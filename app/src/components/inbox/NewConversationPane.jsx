import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useBreakpoint } from '../../hooks/useBreakpoint';
import { findConversationWith, fetchUserProfile, startConversation } from '../../services/inboxApi';
import { uploadMedia } from '../../services/postingApi';
import { friendlyError } from '../../services/socialApi';
import { ChatComposer, isSendableImage } from './ChatComposer';
import { ChatHeader } from './ChatHeader';

/**
 * `/inbox?user=<username>` — "Message" from a profile or the New message picker.
 * Reuses the existing open/pending thread when there is one; otherwise shows an
 * empty composer, and the first send creates the conversation (POST
 * /api/conversations) and swaps to its thread. A 403 (their message settings)
 * shows the backend's explanation.
 */
export function NewConversationPane({ username }) {
  const navigate = useNavigate();
  const { showRail } = useBreakpoint();
  const [phase, setPhase] = useState('checking'); // checking | compose | error
  const [profile, setProfile] = useState(null);
  const [error, setError] = useState(null);
  const [draft, setDraft] = useState('');
  const [sending, setSending] = useState(false);

  useEffect(() => {
    let cancelled = false;
    setPhase('checking');
    setError(null);
    setProfile(null);
    findConversationWith(username)
      .then((conversation) => {
        if (cancelled) return;
        if (conversation?.id) {
          navigate(`/inbox/thread/${conversation.id}`, { replace: true });
          return;
        }
        setPhase('compose');
        fetchUserProfile(username)
          .then((p) => !cancelled && setProfile(p))
          .catch(() => {});
      })
      .catch((e) => {
        if (cancelled) return;
        setError(friendlyError(e));
        setPhase('error');
      });
    return () => {
      cancelled = true;
    };
  }, [username, navigate]);

  const start = async ({ message, imageFile }) => {
    if (sending) return;
    setSending(true);
    setError(null);
    try {
      const imageUrl = imageFile ? await uploadMedia(imageFile, 'chat') : undefined;
      const res = await startConversation({ username, message, imageUrl });
      navigate(`/inbox/thread/${res.id}`, { replace: true });
    } catch (e) {
      setError(friendlyError(e));
      if (message) setDraft(message);
      setSending(false);
    }
  };

  const sendText = () => {
    const message = draft.trim();
    if (!message) return;
    setDraft('');
    start({ message });
  };

  const sendImage = (file) => {
    if (!isSendableImage(file)) {
      setError('Choose a JPEG, PNG or WebP image.');
      return;
    }
    start({ imageFile: file });
  };

  const goBack = () => (showRail ? navigate('/inbox?tab=chats') : navigate(-1));

  return (
    <div style={{ background: 'var(--chat-bg)', minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      <ChatHeader
        onBack={goBack}
        name={profile?.name}
        username={profile?.username || username}
        avatarUrl={profile?.profilePhotoUrl}
      />
      <div style={{ flex: 1, padding: 16, display: 'flex', flexDirection: 'column', justifyContent: 'center', alignItems: 'center', gap: 8 }}>
        {phase === 'checking' ? (
          <span
            style={{
              width: 20,
              height: 20,
              borderRadius: '50%',
              border: '2px solid var(--slate-200)',
              borderTopColor: 'var(--slate-900)',
              animation: 'app-spin 0.7s linear infinite',
            }}
          />
        ) : (
          <p style={{ textAlign: 'center', fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--chat-timestamp)' }}>
            {phase === 'error' ? error : sending ? 'Sending…' : 'Say hello — this is the start of your conversation.'}
          </p>
        )}
        {phase === 'compose' && error && (
          <p style={{ textAlign: 'center', fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--cream-status-error, #e05252)', maxWidth: 360 }}>
            {error}
          </p>
        )}
      </div>
      {phase === 'compose' && (
        <ChatComposer value={draft} onChange={setDraft} onSend={sendText} onPickImage={sendImage} busy={sending} />
      )}
    </div>
  );
}
