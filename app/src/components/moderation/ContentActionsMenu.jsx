import React, { useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { MoreHorizontal, Flag, Ban } from 'lucide-react';
import { blockUser, getSessionUser, isLoggedIn, reportContent } from '../../lib/api';

const DANGER = '#E05252';

// Must match the backend's REPORT_REASONS.
const REASONS = [
  ['inappropriate', 'Nudity, violence, or other objectionable content'],
  ['harassment', 'Harassment, hate, or bullying'],
  ['spam', 'Spam or scam'],
  ['stolen_work', 'Stolen or copied artwork'],
  ['other', 'Something else'],
];

const NOUNS = { piece: 'piece', post: 'scene', comment: 'comment', user: 'account' };

const overlayStyle = {
  position: 'fixed',
  inset: 0,
  background: 'rgba(15, 23, 42, 0.45)',
  display: 'flex',
  alignItems: 'flex-end',
  justifyContent: 'center',
  zIndex: 50,
};

const sheetStyle = {
  width: '100%',
  maxWidth: 480,
  background: 'var(--white)',
  borderRadius: '20px 20px 0 0',
  padding: '16px 16px calc(16px + env(safe-area-inset-bottom))',
  boxSizing: 'border-box',
};

const rowStyle = {
  display: 'flex',
  alignItems: 'center',
  gap: 12,
  width: '100%',
  padding: '14px 8px',
  background: 'none',
  border: 'none',
  color: DANGER,
  fontSize: 15,
  fontWeight: 600,
  textAlign: 'left',
  cursor: 'pointer',
};

const primaryStyle = (enabled) => ({
  width: '100%',
  height: 48,
  borderRadius: 14,
  border: 'none',
  background: enabled ? DANGER : 'var(--slate-300)',
  color: enabled ? 'var(--white)' : 'var(--slate-500)',
  fontSize: 15,
  fontWeight: 600,
  cursor: enabled ? 'pointer' : 'not-allowed',
});

const secondaryStyle = {
  width: '100%',
  height: 44,
  marginTop: 8,
  border: 'none',
  background: 'none',
  color: 'var(--slate-500)',
  fontSize: 14,
  cursor: 'pointer',
};

function Sheet({ onClose, children }) {
  return (
    <div style={overlayStyle} onClick={onClose} role="presentation">
      <div
        style={sheetStyle}
        role="dialog"
        aria-modal="true"
        onClick={(e) => e.stopPropagation()}
      >
        {children}
      </div>
    </div>
  );
}

/// "•••" menu for someone else's piece, scene, comment, or profile: Report it,
/// and Block the account behind it — the same options the iOS/Android app
/// offers (App Store guideline 1.2). Both need an account, so a signed-out
/// visitor is sent to /login and brought back here afterwards.
///
/// `target` is `{ type: 'piece' | 'post' | 'comment' | 'user', id }` (a username
/// for users). `onBlocked` runs after a successful block.
export function ContentActionsMenu({ target, authorUsername, onBlocked, buttonStyle }) {
  const navigate = useNavigate();
  const location = useLocation();
  const [view, setView] = useState(null); // null | 'menu' | 'report' | 'block'
  const [reason, setReason] = useState(null);
  const [details, setDetails] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [notice, setNotice] = useState(null);

  const me = getSessionUser()?.username?.toLowerCase();
  const canBlock = Boolean(authorUsername) && authorUsername.toLowerCase() !== me;
  const noun = NOUNS[target.type];

  const close = () => {
    setView(null);
    setReason(null);
    setDetails('');
    setError(null);
    setBusy(false);
  };

  const requireLogin = (next) => {
    if (isLoggedIn()) {
      setView(next);
      return;
    }
    close();
    navigate(`/login?next=${encodeURIComponent(location.pathname)}`);
  };

  const handleError = (e) => {
    if (e.status === 401) {
      close();
      navigate(`/login?next=${encodeURIComponent(location.pathname)}`);
      return;
    }
    setBusy(false);
    setError(e.message);
  };

  const submitReport = async () => {
    if (!reason || busy) return;
    setBusy(true);
    setError(null);
    try {
      await reportContent(target, reason, details);
      close();
      setNotice('Thanks — we received your report and will review it within 24 hours.');
    } catch (e) {
      handleError(e);
    }
  };

  const confirmBlock = async () => {
    if (busy) return;
    setBusy(true);
    setError(null);
    try {
      await blockUser(authorUsername);
      close();
      setNotice(`Blocked @${authorUsername}.`);
      onBlocked?.();
    } catch (e) {
      handleError(e);
    }
  };

  return (
    <>
      <button
        type="button"
        aria-label="More options"
        onClick={() => setView('menu')}
        style={{
          width: 40,
          height: 40,
          borderRadius: '50%',
          border: 'none',
          background: 'rgba(255, 255, 255, 0.8)',
          color: 'var(--slate-900)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          cursor: 'pointer',
          ...buttonStyle,
        }}
      >
        <MoreHorizontal size={22} />
      </button>

      {view === 'menu' && (
        <Sheet onClose={close}>
          <button type="button" style={rowStyle} onClick={() => requireLogin('report')}>
            <Flag size={20} /> Report {noun}
          </button>
          {canBlock && (
            <button type="button" style={rowStyle} onClick={() => requireLogin('block')}>
              <Ban size={20} /> Block @{authorUsername}
            </button>
          )}
          <button type="button" style={secondaryStyle} onClick={close}>
            Cancel
          </button>
        </Sheet>
      )}

      {view === 'report' && (
        <Sheet onClose={close}>
          <div style={{ fontSize: 18, fontWeight: 600, color: 'var(--slate-900)' }}>
            Report {noun}
          </div>
          <div style={{ fontSize: 13, color: 'var(--slate-500)', margin: '4px 0 12px' }}>
            Why are you reporting this? Your report is anonymous.
          </div>
          {REASONS.map(([value, label]) => (
            <label
              key={value}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 10,
                padding: '8px 2px',
                fontSize: 14,
                color: 'var(--slate-800)',
                cursor: 'pointer',
              }}
            >
              <input
                type="radio"
                name="report-reason"
                value={value}
                checked={reason === value}
                onChange={() => setReason(value)}
              />
              {label}
            </label>
          ))}
          <textarea
            value={details}
            onChange={(e) => setDetails(e.target.value)}
            maxLength={1000}
            rows={3}
            placeholder="Add details (optional)"
            style={{
              width: '100%',
              boxSizing: 'border-box',
              margin: '10px 0 12px',
              padding: 12,
              borderRadius: 12,
              border: '1.5px solid var(--slate-200)',
              fontSize: 14,
              fontFamily: 'inherit',
              resize: 'vertical',
            }}
          />
          {error && <div style={{ color: DANGER, fontSize: 13, marginBottom: 8 }}>{error}</div>}
          <button
            type="button"
            style={primaryStyle(Boolean(reason) && !busy)}
            disabled={!reason || busy}
            onClick={submitReport}
          >
            {busy ? 'Sending…' : 'Submit report'}
          </button>
          <button type="button" style={secondaryStyle} onClick={close}>
            Cancel
          </button>
        </Sheet>
      )}

      {view === 'block' && (
        <Sheet onClose={close}>
          <div style={{ fontSize: 18, fontWeight: 600, color: 'var(--slate-900)' }}>
            Block @{authorUsername}?
          </div>
          <p style={{ fontSize: 14, lineHeight: 1.5, color: 'var(--slate-600)', margin: '8px 0 16px' }}>
            You won't see their pieces, scenes, or comments, and they can't message you.
            They won't be notified. You can unblock anytime from Settings → Blocked accounts
            in the Studio3 app.
          </p>
          {error && <div style={{ color: DANGER, fontSize: 13, marginBottom: 8 }}>{error}</div>}
          <button
            type="button"
            style={primaryStyle(!busy)}
            disabled={busy}
            onClick={confirmBlock}
          >
            {busy ? 'Blocking…' : 'Block'}
          </button>
          <button type="button" style={secondaryStyle} onClick={close}>
            Cancel
          </button>
        </Sheet>
      )}

      {notice && (
        <div
          role="status"
          style={{
            position: 'fixed',
            left: '50%',
            bottom: 24,
            transform: 'translateX(-50%)',
            maxWidth: 440,
            width: 'calc(100% - 32px)',
            boxSizing: 'border-box',
            padding: '12px 16px',
            borderRadius: 12,
            background: 'var(--slate-900)',
            color: 'var(--white)',
            fontSize: 14,
            zIndex: 60,
            display: 'flex',
            justifyContent: 'space-between',
            gap: 12,
          }}
        >
          <span>{notice}</span>
          <button
            type="button"
            onClick={() => setNotice(null)}
            style={{ background: 'none', border: 'none', color: 'inherit', cursor: 'pointer' }}
          >
            OK
          </button>
        </div>
      )}
    </>
  );
}
