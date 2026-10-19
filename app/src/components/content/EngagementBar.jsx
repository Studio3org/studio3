import React from 'react';
import { Heart, MessageCircle } from 'lucide-react';
import './EngagementBar.css';

function countLabel(n) {
  if (n == null) return '';
  return Number(n).toLocaleString();
}

/// Like toggle + comment count for a piece or scene. The comment button just scrolls
/// to the comments section the page renders below.
export function EngagementBar({ liked, likeCount, onLike, likeBusy, commentCount, onComments }) {
  return (
    <div className="s3-engagement">
      <button
        type="button"
        className={`s3-engagement-btn${liked ? ' is-active' : ''}`}
        aria-pressed={liked}
        aria-label={liked ? 'Unlike' : 'Like'}
        onClick={onLike}
        disabled={likeBusy}
      >
        <Heart size={18} strokeWidth={1.6} />
        <span>{countLabel(likeCount ?? 0)}</span>
      </button>
      <button type="button" className="s3-engagement-btn" aria-label="Comments" onClick={onComments}>
        <MessageCircle size={18} strokeWidth={1.6} />
        <span>{countLabel(commentCount ?? 0)}</span>
      </button>
    </div>
  );
}
