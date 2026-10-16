import React, { useState } from 'react';
import { Ban, Flag } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { useRequireLogin } from '../../hooks/useRequireLogin';
import { ActionSheet, SheetItem } from '../common/ActionSheet';
import {
  REPORT_REASONS,
  blockUser,
  friendlyError,
  reportContent,
} from '../../services/socialApi';
import { markBlocked } from '../../services/blockedAuthors';

const NOUNS = { piece: 'piece', post: 'scene', comment: 'comment', user: 'account' };

/**
 * "⋯" sheet for someone else's piece, scene, comment, profile, or chat: the screen's own
 * items (Copy link, Share…) plus Report and Block — the same options the iOS/Android app
 * offers (App Store guideline 1.2). Both are account actions, so a guest is sent to log in.
 *
 * @param {object} props
 * @param {{ type: 'piece'|'post'|'comment'|'user', id: string }} props.target — `id` is the username for users
 * @param {string} [props.authorUsername] — whose content it is; omit to hide Block
 * @param {Array<{ label: string, icon?: React.ReactNode, onClick: () => void }>} [props.items] — screen-specific rows shown first
 * @param {() => void} props.onClose
 * @param {() => void} [props.onBlocked] — e.g. navigate away, since that account's content is now hidden
 * @param {(message: string) => void} [props.onNotice] — toast callback for "Report sent" / "Blocked"
 */
export function ContentActionsSheet({ target, authorUsername, items = [], onClose, onBlocked, onNotice }) {
  const { user } = useAuth();
  const requireLogin = useRequireLogin();
  const [view, setView] = useState('menu'); // menu | report | block
  const [reason, setReason] = useState(null);
  const [details, setDetails] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  const noun = NOUNS[target.type];
  const isMine =
    Boolean(user?.username) &&
    Boolean(authorUsername) &&
    user.username.toLowerCase() === authorUsername.toLowerCase();
  const canBlock = Boolean(authorUsername) && !isMine;

  const go = (next) => {
    if (!requireLogin()) return;
    setError(null);
    setView(next);
  };

  const submitReport = async () => {
    if (!reason || busy) return;
    setBusy(true);
    setError(null);
    try {
      await reportContent(target, reason, details);
      onNotice?.('Thanks — we received your report and will review it within 24 hours.');
      onClose();
    } catch (e) {
      setError(friendlyError(e));
      setBusy(false);
    }
  };

  const confirmBlock = async () => {
    if (busy) return;
    setBusy(true);
    setError(null);
    try {
      await blockUser(authorUsername);
      markBlocked(authorUsername);
      onNotice?.(`Blocked @${authorUsername}`);
      onClose();
      onBlocked?.();
    } catch (e) {
      setError(friendlyError(e));
      setBusy(false);
    }
  };

  if (view === 'report') {
    return (
      <ActionSheet
        title={`Report ${noun}`}
        subtitle="Why are you reporting this? Your report is anonymous."
        onClose={onClose}
      >
        {REPORT_REASONS.map(([value, label]) => (
          <label key={value} className="s3-sheet-radio">
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
          className="s3-sheet-textarea"
          value={details}
          onChange={(e) => setDetails(e.target.value)}
          maxLength={1000}
          placeholder="Add details (optional)"
        />
        {error && <p className="s3-sheet-error">{error}</p>}
        <div className="s3-sheet-actions">
          <button
            type="button"
            className="s3-sheet-btn s3-sheet-btn--danger"
            disabled={!reason || busy}
            onClick={submitReport}
          >
            {busy ? 'Sending…' : 'Submit report'}
          </button>
          <button type="button" className="s3-sheet-btn s3-sheet-btn--ghost" onClick={onClose}>
            Cancel
          </button>
        </div>
      </ActionSheet>
    );
  }

  if (view === 'block') {
    return (
      <ActionSheet
        title={`Block @${authorUsername}?`}
        subtitle="You won't see their pieces, scenes, or comments, and they can't message you. They won't be notified. You can unblock them anytime in Settings → Blocked accounts."
        onClose={onClose}
      >
        {error && <p className="s3-sheet-error">{error}</p>}
        <div className="s3-sheet-actions">
          <button
            type="button"
            className="s3-sheet-btn s3-sheet-btn--danger"
            disabled={busy}
            onClick={confirmBlock}
          >
            {busy ? 'Blocking…' : 'Block'}
          </button>
          <button type="button" className="s3-sheet-btn s3-sheet-btn--ghost" onClick={onClose}>
            Cancel
          </button>
        </div>
      </ActionSheet>
    );
  }

  return (
    <ActionSheet onClose={onClose}>
      {items.map((item) => (
        <SheetItem
          key={item.label}
          icon={item.icon}
          onClick={() => {
            onClose();
            item.onClick();
          }}
        >
          {item.label}
        </SheetItem>
      ))}
      {!isMine && (
        <SheetItem danger icon={<Flag size={18} />} onClick={() => go('report')}>
          Report {noun}
        </SheetItem>
      )}
      {canBlock && (
        <SheetItem danger icon={<Ban size={18} />} onClick={() => go('block')}>
          Block @{authorUsername}
        </SheetItem>
      )}
    </ActionSheet>
  );
}
