import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { PillInput } from '../components/inputs/PillInput';
import { PrimaryButton } from '../components/buttons/PrimaryButton';

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

export function PostPage() {
  const navigate = useNavigate();
  const [type, setType] = useState('piece');
  const [media, setMedia] = useState(null);
  const [title, setTitle] = useState('');
  const [story, setStory] = useState('');
  const [year, setYear] = useState('');
  const [listForSale, setListForSale] = useState(false);
  const [price, setPrice] = useState('');
  const [caption, setCaption] = useState('');
  const [tags, setTags] = useState([]);

  return (
    <div style={modalStyle}>
      <header
        style={{
          padding: '16px 16px 12px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          borderBottom: '1px solid var(--slate-100)',
        }}
      >
        <button style={{ fontSize: 15, color: 'var(--slate-500)' }} onClick={() => navigate(-1)}>Cancel</button>
        <h2 style={{ fontSize: 16, fontWeight: 600, color: 'var(--slate-900)' }}>New Post</h2>
        <button
          style={{
            fontSize: 15,
            fontWeight: 600,
            color: media ? 'var(--slate-900)' : 'var(--slate-300)',
          }}
          disabled={!media}
        >
          Share
        </button>
      </header>

      <div style={{ padding: '0 16px', marginBottom: 16 }}>
        <div style={{ display: 'flex', gap: 8 }}>
          <button
            style={{
              padding: '8px 16px',
              borderRadius: 9999,
              fontSize: 14,
              fontWeight: 500,
              background: type === 'piece' ? 'var(--slate-900)' : 'var(--slate-100)',
              color: type === 'piece' ? 'var(--white)' : 'var(--slate-600)',
            }}
            onClick={() => setType('piece')}
          >
            Piece
          </button>
          <button
            style={{
              padding: '8px 16px',
              borderRadius: 9999,
              fontSize: 14,
              fontWeight: 500,
              background: type === 'post' ? 'var(--slate-900)' : 'var(--slate-100)',
              color: type === 'post' ? 'var(--white)' : 'var(--slate-600)',
            }}
            onClick={() => setType('post')}
          >
            Post
          </button>
        </div>
      </div>

      <div style={{ flex: 1, overflow: 'auto', padding: '0 16px 24px' }}>
        <div
          style={{
            position: 'relative',
            width: '100%',
            maxWidth: 320,
            height: 280,
            margin: '0 auto 20px',
            borderRadius: 16,
            border: '2px dashed var(--slate-300)',
            background: media ? 'var(--slate-200)' : 'var(--slate-100)',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            color: 'var(--slate-400)',
            fontSize: 14,
          }}
          onClick={() => !media && setMedia('placeholder')}
        >
          {media ? (
            <>
              <div style={{ width: '100%', height: '100%', position: 'absolute', inset: 0, background: 'var(--slate-200)', borderRadius: 14 }} />
              <button
                type="button"
                style={{
                  position: 'absolute',
                  bottom: 12,
                  padding: '6px 14px',
                  borderRadius: 9999,
                  background: 'var(--slate-200)',
                  fontSize: 12,
                  fontWeight: 500,
                  zIndex: 1,
                }}
                onClick={(e) => { e.stopPropagation(); setMedia(null); }}
              >
                Change
              </button>
            </>
          ) : (
            <>Tap to add photo or video</>
          )}
        </div>

        {type === 'piece' && (
          <>
            <div style={{ marginBottom: 16 }}>
              <PillInput placeholder="Title (required)" value={title} onChange={(e) => setTitle(e.target.value)} />
            </div>
            <textarea
              placeholder="Story / Intent (optional)"
              value={story}
              onChange={(e) => setStory(e.target.value)}
              style={{
                width: '100%',
                minHeight: 80,
                borderRadius: 16,
                background: 'var(--slate-50)',
                border: '1.5px solid var(--slate-200)',
                padding: 14,
                fontSize: 14,
                marginBottom: 16,
              }}
            />
            <div style={{ marginBottom: 16 }}>
              <PillInput placeholder="Year (optional)" value={year} onChange={(e) => setYear(e.target.value)} />
            </div>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
              <span style={{ fontSize: 15, color: 'var(--slate-700)' }}>List for Sale</span>
              <button
                style={{
                  width: 50,
                  height: 28,
                  borderRadius: 14,
                  background: listForSale ? 'var(--slate-900)' : 'var(--slate-300)',
                  position: 'relative',
                }}
                onClick={() => setListForSale((s) => !s)}
              >
                <span
                  style={{
                    position: 'absolute',
                    top: 2,
                    left: listForSale ? 24 : 2,
                    width: 24,
                    height: 24,
                    borderRadius: '50%',
                    background: 'var(--white)',
                    transition: 'left 0.2s',
                  }}
                />
              </button>
            </div>
            {listForSale && (
              <div style={{ marginBottom: 16 }}>
                <PillInput placeholder="Price ($)" value={price} onChange={(e) => setPrice(e.target.value)} />
              </div>
            )}
            <p style={{ fontSize: 12, color: 'var(--slate-500)', marginBottom: 8 }}>Tags (up to 10)</p>
            <PillInput placeholder="Add tags..." />
          </>
        )}

        {type === 'post' && (
          <>
            <textarea
              placeholder="Caption"
              value={caption}
              onChange={(e) => setCaption(e.target.value)}
              maxLength={2000}
              style={{
                width: '100%',
                minHeight: 100,
                borderRadius: 16,
                border: '1.5px solid var(--slate-200)',
                padding: 14,
                fontSize: 14,
                marginBottom: 8,
              }}
            />
            <p style={{ fontSize: 12, color: 'var(--slate-400)', marginBottom: 16 }}>{caption.length}/2000</p>
            <button
              style={{
                width: '100%',
                padding: 14,
                borderRadius: 12,
                border: '1.5px solid var(--slate-200)',
                background: 'var(--white)',
                fontSize: 14,
                color: 'var(--slate-500)',
                textAlign: 'left',
              }}
            >
              Link to a Piece (optional)
            </button>
          </>
        )}
      </div>
    </div>
  );
}
