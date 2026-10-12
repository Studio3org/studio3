import React, { useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { PillInput } from '../components/inputs/PillInput';
import { PrimaryButton } from '../components/buttons/PrimaryButton';
import { GhostButton } from '../components/buttons/GhostButton';
import { GuestPrompt } from '../components/common/StateMessage';
import { MediaPicker } from '../components/post/MediaPicker';
import { LinkPiecePicker, MaterialsPicker, SeriesPicker } from '../components/post/Pickers';
import {
  AspectPicker,
  ChipGroup,
  ErrorText,
  Field,
  ToggleRow,
  selectStyle,
  textAreaStyle,
} from '../components/post/FormBits';
import { useSession } from '../lib/session';
import { friendlyError } from '../lib/social';
import { IMAGE_TYPES, VIDEO_TYPES, defaultAspectFor, isVideoFile, readImageSize, validateMediaFile } from '../lib/media';
import {
  MAX_PIECE_IMAGES,
  MEDIUM_OPTIONS,
  STYLE_MAX_SELECTIONS,
  STYLE_OPTIONS,
  dimensionsString,
  publishPiece,
  publishScene,
} from '../lib/postApi';

const modalStyle = {
  position: 'fixed',
  inset: 0,
  background: 'var(--white)',
  zIndex: 200,
  display: 'flex',
  flexDirection: 'column',
  maxWidth: 375,
  margin: '0 auto',
  boxShadow: '0 24px 64px rgba(15,23,42,0.2)',
};

const TITLE_MAX = 200;
const CAPTION_MAX = 2000;

function Header({ onCancel, onShare, canShare, busy }) {
  return (
    <header
      style={{
        padding: '16px 16px 12px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        borderBottom: '1px solid var(--slate-100)',
        marginBottom: 16,
      }}
    >
      <button style={{ fontSize: 15, color: 'var(--slate-500)' }} onClick={onCancel} disabled={busy}>
        Cancel
      </button>
      <h2 style={{ fontSize: 16, fontWeight: 600, color: 'var(--slate-900)' }}>New Post</h2>
      <button
        style={{ fontSize: 15, fontWeight: 600, color: canShare ? 'var(--slate-900)' : 'var(--slate-300)' }}
        disabled={!canShare}
        onClick={onShare}
      >
        {busy ? 'Sharing…' : 'Share'}
      </button>
    </header>
  );
}

/// /post — create a Piece (artwork, optionally for sale) or a Scene (photo /
/// video moment). Account-only, like the app's create tab.
export function PostPage() {
  const navigate = useNavigate();
  const { loggedIn, user } = useSession();
  if (!loggedIn) {
    return (
      <div style={modalStyle}>
        <Header onCancel={() => navigate(-1)} canShare={false} />
        <GuestPrompt
          title="Share your work"
          message="Log in or create an account to post pieces and scenes."
          next="/post"
        />
      </div>
    );
  }
  return <PostComposer user={user} />;
}

function PostComposer({ user }) {
  const navigate = useNavigate();
  const [type, setType] = useState('piece');

  // Media (`{file, url, isVideo}`; object URLs revoked on removal/unmount).
  const [media, setMedia] = useState([]);
  const [aspect, setAspect] = useState('3:4');
  const aspectTouched = useRef(false);
  const mediaRef = useRef(media);
  mediaRef.current = media;
  useEffect(() => () => mediaRef.current.forEach((m) => URL.revokeObjectURL(m.url)), []);

  // Piece fields.
  const [title, setTitle] = useState('');
  const [story, setStory] = useState('');
  const [medium, setMedium] = useState('');
  const [year, setYear] = useState('');
  const [materials, setMaterials] = useState([]);
  const [styles, setStyles] = useState([]);
  const [aiDisclosed, setAiDisclosed] = useState(false);
  const [altText, setAltText] = useState('');
  const [listForSale, setListForSale] = useState(false);
  const [price, setPrice] = useState('');
  const [dims, setDims] = useState({ width: '', height: '', depth: '', unit: 'in' });
  const [shippingRegion, setShippingRegion] = useState('');
  const [series, setSeries] = useState({ seriesId: null, newName: null });

  // Scene fields.
  const [caption, setCaption] = useState('');
  const [isProcess, setIsProcess] = useState(false);
  const [linkedPieceId, setLinkedPieceId] = useState(null);

  // Shared.
  const [location, setLocation] = useState('');
  const [busy, setBusy] = useState(false);
  const [progress, setProgress] = useState(null);
  const [error, setError] = useState(null);
  const [mediaError, setMediaError] = useState(null);
  const [seriesFailure, setSeriesFailure] = useState(null);
  const submitting = useRef(false);
  const errorRef = useRef(null);
  // The header's Share button is far from the form's error line.
  useEffect(() => {
    if (error) errorRef.current?.scrollIntoView({ block: 'center', behavior: 'smooth' });
  }, [error]);

  const isPiece = type === 'piece';
  const hasVideo = media.some((m) => m.isVideo);

  const clearMedia = () => {
    media.forEach((m) => URL.revokeObjectURL(m.url));
    setMedia([]);
    aspectTouched.current = false;
  };

  const switchType = (next) => {
    if (next === type || busy) return;
    // A scene holds one file (maybe a video); a piece holds images only.
    if (next === 'piece' ? hasVideo : media.length > 1) clearMedia();
    setType(next);
    setError(null);
    setMediaError(null);
  };

  const addFiles = async (files) => {
    setMediaError(null);
    const room = isPiece ? MAX_PIECE_IMAGES - media.length : 1;
    const errors = [];
    const accepted = [];
    for (const file of files) {
      const err = validateMediaFile(file, { allowVideo: !isPiece });
      if (err) errors.push(err);
      else accepted.push(file);
    }
    if (accepted.length > room) {
      errors.push(isPiece ? `A piece can have up to ${MAX_PIECE_IMAGES} images.` : 'A scene has one photo or video.');
    }
    const kept = accepted.slice(0, room);
    if (errors.length) setMediaError(errors.join(' '));
    if (!kept.length) return;

    const items = kept.map((file) => ({ file, url: URL.createObjectURL(file), isVideo: isVideoFile(file) }));
    // Scene: picking again replaces the current file.
    const next = isPiece ? [...media, ...items] : items;
    if (!isPiece) media.forEach((m) => URL.revokeObjectURL(m.url));
    setMedia(next);

    // Default the crop ratio from the cover's shape until the user picks one.
    if (!aspectTouched.current && !next[0].isVideo) {
      const size = await readImageSize(next[0].file);
      if (!aspectTouched.current) setAspect(defaultAspectFor(size));
    }
  };

  const removeAt = (i) => {
    URL.revokeObjectURL(media[i].url);
    const next = media.filter((_, j) => j !== i);
    setMedia(next);
    if (!next.length) aspectTouched.current = false;
  };

  const makeCover = (i) => setMedia([media[i], ...media.filter((_, j) => j !== i)]);

  const toggleStyle = (id) => {
    setStyles((s) => {
      if (s.includes(id)) return s.filter((x) => x !== id);
      return s.length >= STYLE_MAX_SELECTIONS ? s : [...s, id];
    });
  };

  /// Client-side checks mirroring the backend's, so obvious mistakes don't
  /// cost an upload round-trip.
  const validate = () => {
    if (!media.length) return isPiece ? 'Add at least one image.' : 'Add a photo or video.';
    if (!isPiece) {
      if (caption.length > CAPTION_MAX) return `Caption must be ${CAPTION_MAX} characters or fewer.`;
      return null;
    }
    if (!title.trim()) return 'Give your piece a title.';
    if (title.trim().length > TITLE_MAX) return `Title must be ${TITLE_MAX} characters or fewer.`;
    if (year) {
      const y = Number(year);
      if (!/^\d{4}$/.test(year) || y < 1000 || y > new Date().getFullYear() + 1) return 'Enter a valid year, e.g. 2024.';
    }
    if (series.newName !== null && !series.newName.trim()) return 'Name your new series, or choose "No series".';
    if (listForSale) {
      const cents = Math.round(Number(price) * 100);
      if (!price || !Number.isFinite(cents) || cents < 100) return 'Price must be at least $1.00.';
      if (!medium) return 'Medium is required to list a piece for sale.';
      const okDim = (v) => v === '' || Number(v) > 0;
      if (!dims.width || !dims.height) return 'Width and height are required to list a piece for sale.';
      if (![dims.width, dims.height, dims.depth].every(okDim)) return 'Dimensions must be positive numbers.';
    }
    return null;
  };

  const submit = async (status) => {
    if (submitting.current) return;
    const problem = validate();
    if (problem) {
      setError(problem);
      return;
    }
    submitting.current = true;
    setBusy(true);
    setError(null);
    setProgress({ done: 0, total: media.length });
    const onProgress = (done, total) => setProgress({ done, total });
    try {
      if (isPiece) {
        const { piece, seriesError } = await publishPiece(
          {
            files: media.map((m) => m.file),
            aspect,
            title,
            caption: story,
            medium,
            yearCreated: year,
            materials,
            styleTags: styles,
            location,
            altText,
            aiDisclosed,
            status,
            forSale: listForSale,
            priceCents: listForSale ? Math.round(Number(price) * 100) : undefined,
            dimensions: listForSale ? dimensionsString(dims) : undefined,
            shippingRegion,
            seriesId: series.seriesId,
            newSeriesName: series.newName,
          },
          onProgress,
        );
        const dest = status === 'draft' ? '/profile' : `/piece/${piece.id}`;
        if (seriesError) {
          // The piece exists; don't let a retry post it twice.
          setSeriesFailure({ message: seriesError, dest });
          return;
        }
        navigate(dest, { replace: true });
      } else {
        const post = await publishScene(
          { file: media[0].file, aspect, caption, location, isProcess, linkedPieceId, status },
          onProgress,
        );
        navigate(status === 'draft' ? '/profile' : `/scene/${post.id}`, { replace: true });
      }
    } catch (e) {
      setError(friendlyError(e));
      submitting.current = false;
      setBusy(false);
      setProgress(null);
    }
  };

  const busyLabel = progress && progress.done < progress.total
    ? `Uploading ${Math.min(progress.done + 1, progress.total)} of ${progress.total}…`
    : 'Posting…';

  if (seriesFailure) {
    return (
      <div style={modalStyle}>
        <div style={{ padding: '96px 32px', textAlign: 'center' }}>
          <h2 style={{ fontSize: 18, fontWeight: 600, color: 'var(--slate-900)', marginBottom: 8 }}>Your piece was posted</h2>
          <p style={{ fontSize: 14, color: 'var(--slate-500)', lineHeight: 1.5, marginBottom: 20 }}>
            But it couldn't be added to the series: {seriesFailure.message}
          </p>
          <PrimaryButton onClick={() => navigate(seriesFailure.dest, { replace: true })}>Continue</PrimaryButton>
        </div>
      </div>
    );
  }

  return (
    <div style={modalStyle}>
      <Header
        onCancel={() => navigate(-1)}
        onShare={() => submit('live')}
        canShare={media.length > 0 && !busy}
        busy={busy}
      />

      <div style={{ padding: '0 16px', marginBottom: 16 }}>
        <div style={{ display: 'flex', gap: 8 }}>
          {[
            ['piece', 'Piece'],
            ['scene', 'Scene'],
          ].map(([id, label]) => (
            <button
              key={id}
              style={{
                padding: '8px 16px',
                borderRadius: 9999,
                fontSize: 14,
                fontWeight: 500,
                background: type === id ? 'var(--slate-900)' : 'var(--slate-100)',
                color: type === id ? 'var(--white)' : 'var(--slate-600)',
              }}
              onClick={() => switchType(id)}
              disabled={busy}
            >
              {label}
            </button>
          ))}
        </div>
      </div>

      <div style={{ flex: 1, overflow: 'auto', padding: '0 16px 24px' }}>
      {/* A disabled fieldset freezes every input while uploading. */}
      <fieldset disabled={busy} style={{ border: 0, margin: 0, padding: 0, minWidth: 0 }}>
        <MediaPicker
          items={media}
          multiple={isPiece}
          max={MAX_PIECE_IMAGES}
          accept={(isPiece ? IMAGE_TYPES : [...IMAGE_TYPES, ...VIDEO_TYPES]).join(',')}
          aspect={aspect}
          onAdd={addFiles}
          onRemove={removeAt}
          onMakeCover={makeCover}
          disabled={busy}
        />
        <ErrorText>{mediaError}</ErrorText>

        {media.length > 0 && !hasVideo && (
          <Field label="Crop">
            <AspectPicker
              value={aspect}
              onChange={(v) => {
                aspectTouched.current = true;
                setAspect(v);
              }}
            />
          </Field>
        )}

        {isPiece ? (
          <>
            <Field label="Title" hint={`${title.length}/${TITLE_MAX}`}>
              <PillInput placeholder="Title (required)" value={title} maxLength={TITLE_MAX} onChange={(e) => setTitle(e.target.value)} />
            </Field>
            <Field label="Story / Intent">
              <textarea
                placeholder="What's this piece about? (optional)"
                value={story}
                onChange={(e) => setStory(e.target.value)}
                maxLength={CAPTION_MAX}
                style={textAreaStyle}
              />
            </Field>
            <Field label="Medium" hint={listForSale ? 'Required for sale' : undefined}>
              <select value={medium} onChange={(e) => setMedium(e.target.value)} style={selectStyle}>
                <option value="">Select a medium</option>
                {MEDIUM_OPTIONS.map((m) => (
                  <option key={m.id} value={m.id}>{m.name}</option>
                ))}
              </select>
            </Field>
            <Field label="Style" hint={`Up to ${STYLE_MAX_SELECTIONS}`}>
              <ChipGroup options={STYLE_OPTIONS} selected={styles} onToggle={toggleStyle} />
            </Field>
            <Field label="Materials">
              <MaterialsPicker value={materials} onChange={setMaterials} />
            </Field>
            <Field label="Year">
              <PillInput
                placeholder="Year created (optional)"
                inputMode="numeric"
                maxLength={4}
                value={year}
                onChange={(e) => setYear(e.target.value.replace(/\D/g, ''))}
              />
            </Field>
            <Field label="Location">
              <PillInput placeholder="Where was it made? (optional)" value={location} onChange={(e) => setLocation(e.target.value)} />
            </Field>
            <Field label="Alt text" hint="Describes the image for screen readers">
              <PillInput placeholder="Alt text (optional)" value={altText} maxLength={500} onChange={(e) => setAltText(e.target.value)} />
            </Field>
            <ToggleRow
              title="Made with AI"
              subtitle="Disclose if generative AI was used to create this piece."
              on={aiDisclosed}
              onChange={setAiDisclosed}
            />
            <Field label="Series">
              <SeriesPicker
                seriesId={series.seriesId}
                newName={series.newName}
                onChange={setSeries}
              />
            </Field>

            <ToggleRow
              title="List for Sale"
              subtitle={
                user?.sellerEnabled
                  ? undefined
                  : 'Selling requires seller mode and payout setup in the Studio3 app.'
              }
              on={listForSale}
              onChange={setListForSale}
            />
            {listForSale && (
              <div style={{ padding: 14, borderRadius: 16, background: 'var(--slate-50)', border: '1.5px solid var(--slate-200)', marginBottom: 16 }}>
                <Field label="Price (USD)">
                  <PillInput
                    placeholder="$0.00"
                    inputMode="decimal"
                    value={price}
                    onChange={(e) => setPrice(e.target.value.replace(/[^\d.]/g, ''))}
                  />
                </Field>
                <Field label="Dimensions" hint="Required for sale">
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr 64px', gap: 6 }}>
                    {[
                      ['width', 'W'],
                      ['height', 'H'],
                      ['depth', 'D'],
                    ].map(([k, ph]) => (
                      <input
                        key={k}
                        placeholder={ph}
                        inputMode="decimal"
                        aria-label={k}
                        value={dims[k]}
                        onChange={(e) => setDims((d) => ({ ...d, [k]: e.target.value.replace(/[^\d.]/g, '') }))}
                        style={{ ...selectStyle, padding: '0 12px', height: 44, minWidth: 0, textAlign: 'center' }}
                      />
                    ))}
                    <select
                      value={dims.unit}
                      aria-label="Unit"
                      onChange={(e) => setDims((d) => ({ ...d, unit: e.target.value }))}
                      style={{ ...selectStyle, padding: '0 10px', height: 44, textAlign: 'center' }}
                    >
                      <option value="in">in</option>
                      <option value="cm">cm</option>
                    </select>
                  </div>
                </Field>
                <Field label="Ships from" style={{ marginBottom: 0 }}>
                  <PillInput placeholder="City or region (optional)" value={shippingRegion} onChange={(e) => setShippingRegion(e.target.value)} />
                </Field>
              </div>
            )}
          </>
        ) : (
          <>
            <Field label="Caption" hint={`${caption.length}/${CAPTION_MAX}`}>
              <textarea
                placeholder="Caption"
                value={caption}
                onChange={(e) => setCaption(e.target.value)}
                maxLength={CAPTION_MAX}
                style={{ ...textAreaStyle, minHeight: 100, background: 'var(--white)' }}
              />
            </Field>
            <Field label="Location">
              <PillInput placeholder="Location (optional)" value={location} onChange={(e) => setLocation(e.target.value)} />
            </Field>
            <ToggleRow
              title="This is process"
              subtitle="Work in progress, studio shots, sketches."
              on={isProcess}
              onChange={setIsProcess}
            />
            <Field>
              <LinkPiecePicker username={user?.username} value={linkedPieceId} onChange={setLinkedPieceId} />
            </Field>
          </>
        )}

        <div ref={errorRef}>
          <ErrorText>{error}</ErrorText>
        </div>

        <div style={{ display: 'flex', gap: 10, alignItems: 'center', marginTop: 8 }}>
          <GhostButton
            onClick={() => submit('draft')}
            disabled={busy || !media.length}
            style={{ height: 52, flexShrink: 0, opacity: busy || !media.length ? 0.5 : 1 }}
          >
            Save as draft
          </GhostButton>
          <PrimaryButton onClick={() => submit('live')} disabled={busy || !media.length}>
            {busy ? busyLabel : 'Publish'}
          </PrimaryButton>
        </div>
      </fieldset>
      </div>
    </div>
  );
}
