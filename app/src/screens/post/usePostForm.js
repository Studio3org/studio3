import { useState } from 'react';
import { createPiece, createPost, uploadMedia, uploadMediaSequence } from '../../services/postingApi';
import { renderAllMediaItems, renderMediaItem } from './mediaRenderer';
import { useMediaEditor } from './useMediaEditor';

export const PIECE_TABS = ['Availability', 'Details', 'Review'];
export const SCENE_TABS = ['Details', 'Review'];
export const AUCTION_DURATIONS = [3, 7, 14];

/** All state + the actual publish flow for the Piece/Scene creation form —
 * shared by the mobile full-page flow (PostPage) and the desktop modal
 * (PostModal) so both are, literally, the same posting flow.
 *
 * Flow: `step` gates three linear stages — 'gallery' (pick media, up to 5
 * images for a piece / 1 image-or-video for a scene, see useMediaEditor),
 * 'edit' (reorder + per-image crop/rotate/adjust, see MediaEditStep — a
 * video selection skips this stage entirely), then 'tabs' (the existing
 * freely-revisitable Availability/Details/Review TabBar, untouched). */
export function usePostForm(type, onPublished) {
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
  const [series, setSeries] = useState('');
  const [relatedScenes, setRelatedScenes] = useState([]);
  const [linkedPiece, setLinkedPiece] = useState('');

  // Dimensions & Additional Details
  const [dimWidth, setDimWidth] = useState('');
  const [dimHeight, setDimHeight] = useState('');
  const [dimUnit, setDimUnit] = useState('in');
  const [yearCreated, setYearCreated] = useState('');
  const [framing, setFraming] = useState('');
  const [handling, setHandling] = useState('');
  const [shippingRegion, setShippingRegion] = useState('');

  const [publishing, setPublishing] = useState(false);
  const [error, setError] = useState('');

  const dimensionsStr = dimWidth && dimHeight ? `${dimWidth} x ${dimHeight} ${dimUnit}` : '';

  const priceValid = !forSale || Number(price) > 0;
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

  const publish = async () => {
    if (media.items.length === 0 || publishing) return;
    setPublishing(true);
    setError('');
    try {
      if (type === 'piece') {
        const blobs = await renderAllMediaItems(media.items);
        const images = await uploadMediaSequence(blobs, 'piece'); // array order preserved, index 0 = cover
        await createPiece({
          title: title.trim() || 'Untitled',
          images,
          mediaUrl: images[0].mediaUrl,
          mediaType: images[0].mediaType,
          caption: caption.trim() || undefined,
          location: location || undefined,
          medium: medium.trim() || undefined,
          dimensions: dimensionsStr || undefined,
          materials: materials.length > 0 ? materials : undefined,
          series: series || undefined,
          yearCreated: yearCreated || undefined,
          framing: framing || undefined,
          handling: handling || undefined,
          shippingRegion: shippingRegion.trim() || undefined,
          isForSale: forSale,
          ...(forSale
            ? {
                priceCents: Math.round(Number(price) * 100),
                listingType,
                ...(listingType === 'auction' ? { auctionDurationDays } : {}),
              }
            : {}),
        });
      } else {
        const item = media.items[0];
        const mediaUrl =
          item.mediaType === 'video'
            ? await uploadMedia(item.file, 'post')
            : await uploadMedia(await renderMediaItem(item), 'post');
        await createPost({
          mediaUrl,
          mediaType: item.mediaType,
          caption: caption.trim() || undefined,
          location: location || undefined,
          linkedPieceId: linkedPiece || undefined,
        });
      }
      onPublished?.();
    } catch (e) {
      setError(e?.message || 'Something went wrong publishing this — please try again.');
    } finally {
      setPublishing(false);
    }
  };

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
    publishing,
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
    medium,
    setMedium,
    styles,
    setStyles,
    materials,
    setMaterials,
    series,
    setSeries,
    relatedScenes,
    setRelatedScenes,
    linkedPiece,
    setLinkedPiece,
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

