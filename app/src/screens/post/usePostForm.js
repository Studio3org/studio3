import { useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  addPieceToSeries,
  createPiece,
  createPost,
  createSeries,
  uploadMedia,
  uploadMediaSequence,
} from '../../services/postingApi';
import { friendlyError } from '../../services/socialApi';
import { aspectRatioFor, captureVideoPoster, renderMediaItem } from './mediaRenderer';
import { useMediaEditor } from './useMediaEditor';
import { LOCATION_OPTIONS, MATERIAL_OPTIONS } from './PostPickerOptions';

export const PIECE_TABS = ['Availability', 'Details', 'Review'];
export const SCENE_TABS = ['Details', 'Review'];
export const AUCTION_DURATIONS = [3, 7, 14];

const nameOf = (options, id) => options.find((o) => o.id === id)?.name || id;

/** All state + the actual publish flow for the Piece/Scene creation form —
 * shared by the mobile full-page flow (PostPage) and the desktop modal
 * (PostModal) so both are, literally, the same posting flow.
 *
 * Flow: `step` gates three linear stages — 'gallery' (pick media, up to 5
 * images for a piece / 1 image-or-video for a scene, see useMediaEditor),
 * 'edit' (reorder + per-image crop/rotate/adjust, see MediaEditStep — a
 * video selection skips this stage entirely), then 'tabs' (the
 * freely-revisitable Availability/Details/Review TabBar).
 *
 * On success it navigates to the new piece/scene (drafts → /profile, where the owner
 * sees them), replacing the composer in history so Back doesn't reopen it. */
export function usePostForm(type) {
  const navigate = useNavigate();
  const TABS = type === 'piece' ? PIECE_TABS : SCENE_TABS;
  const media = useMediaEditor(type);
  const [step, setStep] = useState('gallery');
  const [tab, setTab] = useState(TABS[0]);
  const [unlocked, setUnlocked] = useState(1);
  const [forSale, setForSale] = useState(false);
  const [listingType, setListingType] = useState('fixed');
  const [auctionDurationDays, setAuctionDurationDays] = useState(7);
  const [price, setPrice] = useState('');
  const [title, setTitle] = useState('');
  const [caption, setCaption] = useState('');

  // Rich metadata options
  const [location, setLocation] = useState('');
  const [medium, setMedium] = useState('');
  const [styles, setStyles] = useState([]);
  const [materials, setMaterials] = useState([]);
  /** `null` | `{ id, name }` (existing series) | `{ newName }` (created after the piece). */
  const [series, setSeries] = useState(null);
  /** `null` | `{ id, title }` — scene → one of the user's own pieces. */
  const [linkedPiece, setLinkedPiece] = useState(null);
  const [isProcess, setIsProcess] = useState(false);

  // Dimensions & Additional Details
  const [dimWidth, setDimWidth] = useState('');
  const [dimHeight, setDimHeight] = useState('');
  const [dimUnit, setDimUnit] = useState('in');
  const [yearCreated, setYearCreated] = useState('');
  const [framing, setFraming] = useState('');
  const [handling, setHandling] = useState('');
  const [shippingRegion, setShippingRegion] = useState('');

  /** 'live' | 'draft' while a submit is in flight, else null. */
  const [publishing, setPublishing] = useState(null);
  const [error, setError] = useState('');
  /** Set once the piece/scene exists server-side. From then on, submitting again only
   * navigates — a failed follow-up (series assignment) must never cause a second post. */
  const [posted, setPosted] = useState(null);
  const inFlight = useRef(false);

  const dimensionsStr = dimWidth && dimHeight ? `${dimWidth} x ${dimHeight} ${dimUnit}` : '';
  const seriesLabel = series ? series.name || series.newName : '';
  const locationName = location ? nameOf(LOCATION_OPTIONS, location) : '';

  const priceValid = !forSale || Number(price) >= 1;
  const detailsValid = type === 'scene' ? Boolean(caption.trim()) : !forSale || Boolean(medium.trim() && dimensionsStr.trim());
  const canAdvance =
    media.items.length > 0 &&
    (tab !== 'Availability' || priceValid) &&
    (tab !== 'Details' || detailsValid);

  const goToGallery = () => setStep('gallery');
  const goToEdit = () => media.items.length > 0 && setStep('edit');
  const goToTabs = () => setStep('tabs');
  const goToEditOrTabs = () => setStep(media.hasVideo ? 'tabs' : 'edit');

  const goTab = (i) => {
    if (i <= unlocked) setTab(TABS[i]);
  };

  const destinationFor = (kind, created) => {
    if (created.status === 'draft') return '/profile';
    return kind === 'piece' ? `/piece/${created.id}` : `/scene/${created.id}`;
  };

  const pieceBody = (images, status) => ({
    title: title.trim() || 'Untitled',
    images,
    mediaUrl: images[0].mediaUrl,
    mediaType: 'image',
    mediaAspectRatio: images[0].mediaAspectRatio || '3:4',
    caption: caption.trim() || undefined,
    location: locationName || undefined,
    medium: medium.trim() || undefined,
    dimensions: dimensionsStr || undefined,
    // Names, not ids — what the app sends and what the piece page displays.
    materials: materials.length > 0 ? materials.map((id) => nameOf(MATERIAL_OPTIONS, id)) : undefined,
    styleTags: styles.length > 0 ? styles : undefined,
    yearCreated: /^\d{4}$/.test(yearCreated.trim()) ? Number(yearCreated.trim()) : undefined,
    framingMounting: framing.trim() || undefined,
    handlingNotes: handling.trim() || undefined,
    shippingRegion: forSale ? shippingRegion.trim() || undefined : undefined,
    aiDisclosed: false,
    status,
    isForSale: forSale,
    ...(forSale
      ? {
          priceCents: Math.round(Number(price) * 100),
          listingType,
          ...(listingType === 'auction' ? { auctionDurationDays } : {}),
        }
      : {}),
  });

  /** Series is a second call after the piece exists — the backend has no series field on
   * create. Throws with the backend's message (e.g. "already in another series"). */
  const assignSeries = async (pieceId) => {
    if (!series) return;
    if (series.newName) await createSeries(series.newName, [pieceId]);
    else if (series.id) await addPieceToSeries(series.id, pieceId);
  };

  const submit = async (status) => {
    if (media.items.length === 0 || inFlight.current) return;
    if (posted) {
      navigate(posted.href, { replace: true });
      return;
    }
    inFlight.current = true;
    setPublishing(status);
    setError('');
    let created = null;
    try {
      if (type === 'piece') {
        const entries = [];
        for (const item of media.items) {
          entries.push({ blob: await renderMediaItem(item), mediaAspectRatio: aspectRatioFor(item) });
        }
        const images = await uploadMediaSequence(entries, 'piece'); // order preserved, index 0 = cover
        created = await createPiece(pieceBody(images, status));
      } else {
        const item = media.items[0];
        let body;
        if (item.mediaType === 'video') {
          const mediaUrl = await uploadMedia(item.file, 'post');
          let thumbnailUrl;
          try {
            const poster = await captureVideoPoster(item.previewUrl);
            if (poster) thumbnailUrl = await uploadMedia(poster, 'post');
          } catch {
            /* best-effort: the scene still posts without a poster frame */
          }
          body = { mediaUrl, mediaType: 'video', ...(thumbnailUrl ? { thumbnailUrl } : {}) };
        } else {
          const mediaUrl = await uploadMedia(await renderMediaItem(item), 'post');
          body = { mediaUrl, mediaType: 'image', mediaAspectRatio: aspectRatioFor(item) };
        }
        created = await createPost({
          ...body,
          caption: caption.trim() || undefined,
          location: locationName || undefined,
          linkedPieceId: linkedPiece?.id || undefined,
          isProcess,
          status,
        });
      }
    } catch (e) {
      setError(friendlyError(e));
      setPublishing(null);
      inFlight.current = false;
      return;
    }

    const href = destinationFor(type, created || {});
    setPosted({ id: created?.id, href });
    if (type === 'piece' && created?.id) {
      try {
        await assignSeries(created.id);
      } catch (e) {
        setError(
          `Your piece was ${status === 'draft' ? 'saved' : 'posted'}, but it couldn't be added to the series: ${friendlyError(e)} You can add it from the piece page.`,
        );
        setPublishing(null);
        inFlight.current = false;
        return;
      }
    }
    inFlight.current = false;
    navigate(href, { replace: true });
  };

  const publish = () => submit('live');
  const saveDraft = () => submit('draft');

  const advance = () => {
    if (!canAdvance) return;
    const i = TABS.indexOf(tab);
    if (i < TABS.length - 1) {
      setUnlocked(Math.max(unlocked, i + 1));
      setTab(TABS[i + 1]);
    } else {
      publish();
    }
  };

  return {
    type,
    media,
    step,
    goToGallery,
    goToEdit,
    goToTabs,
    goToEditOrTabs,
    TABS,
    tab,
    unlocked,
    goTab,
    advance,
    canAdvance,
    publish,
    saveDraft,
    publishing,
    posted,
    error,
    forSale,
    setForSale,
    listingType,
    setListingType,
    auctionDurationDays,
    setAuctionDurationDays,
    price,
    setPrice,
    title,
    setTitle,
    caption,
    setCaption,
    location,
    setLocation,
    locationName,
    medium,
    setMedium,
    styles,
    setStyles,
    materials,
    setMaterials,
    series,
    setSeries,
    seriesLabel,
    linkedPiece,
    setLinkedPiece,
    isProcess,
    setIsProcess,
    dimWidth,
    setDimWidth,
    dimHeight,
    setDimHeight,
    dimUnit,
    setDimUnit,
    dimensionsStr,
    yearCreated,
    setYearCreated,
    framing,
    setFraming,
    handling,
    setHandling,
    shippingRegion,
    setShippingRegion,
  };
}
