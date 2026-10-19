import React, { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Bookmark, Trash2, FolderPlus, ChevronLeft, MoreHorizontal, Pencil, X, Folder } from 'lucide-react';
import { useBreakpoint } from '../hooks/useBreakpoint';
import { InboxRail } from '../components/layout/InboxRail';
import { ActionSheet, SheetItem, useToast } from '../components/common/ActionSheet';
import { setSaved, friendlyError } from '../services/socialApi';
import { isBlockedAuthor, onAuthorBlocked } from '../services/blockedAuthors';
import { contentHref } from '../utils/contentLinks';
import {
  addToCollection,
  createCollection,
  deleteCollection,
  getCollection,
  listCollections,
  listSavedEvents,
  listSavedPieces,
  listSavedPosts,
  removeFromCollection,
  renameCollection,
  setEventSaved,
} from '../services/savedApi';
import './SavedPage.css';

const TABS = ['all', 'pieces', 'scenes', 'events'];
const isVideoUrl = (url) => /\.(mp4|mov|webm)(\?|$)/i.test(url || '');

/// One grid card's view of a saved piece / scene / event. `type` is the API's
/// 'piece' | 'post' | 'event' (a scene is a post).
function toCard(raw, type) {
  if (type === 'event') {
    return { key: `event:${raw.id}`, id: raw.id, type, title: raw.title, src: raw.coverMediaUrl, author: raw.hostUsername };
  }
  const isVideo = type === 'post' && raw.mediaType === 'video';
  return {
    key: `${type}:${raw.id}`,
    id: raw.id,
    type,
    title: raw.title || raw.caption || (type === 'post' ? 'Scene' : 'Untitled'),
    src: isVideo ? raw.thumbnailUrl : raw.images?.[0]?.mediaUrl || raw.mediaUrl,
    videoSrc: isVideo && !raw.thumbnailUrl ? raw.mediaUrl : null,
    author: raw.author?.username,
  };
}

const badgeFor = (type) => (type === 'post' ? 'scene' : type);

export function SavedPage() {
  const navigate = useNavigate();
  const { railLabeled } = useBreakpoint();
  const [toast, showToast] = useToast();
  const [activeTab, setActiveTab] = useState('all');
  const [pieces, setPieces] = useState([]);
  const [posts, setPosts] = useState([]);
  const [events, setEvents] = useState([]);
  const [collections, setCollections] = useState([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState('');
  const [, setBlockTick] = useState(0);

  /** `null` or `{ id, name, items: card[] | null, error }` — the open collection. */
  const [openCollection, setOpenCollection] = useState(null);
  /** `null` | `{ mode: 'create' | 'rename', value }` — the name modal. */
  const [nameModal, setNameModal] = useState(null);
  const [nameError, setNameError] = useState('');
  const [nameBusy, setNameBusy] = useState(false);
  const [collectionMenuOpen, setCollectionMenuOpen] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  /** The card being added to a collection (shows the picker sheet). */
  const [addTarget, setAddTarget] = useState(null);

  const load = useCallback(() => {
    let cancelled = false;
    setLoading(true);
    setLoadError('');
    // Events are a separate module — a failure there shouldn't hide saved art.
    Promise.all([
      listSavedPieces(),
      listSavedPosts(),
      listCollections(),
      listSavedEvents().catch(() => []),
    ])
      .then(([p, s, c, e]) => {
        if (cancelled) return;
        setPieces(p.map((x) => toCard(x, 'piece')));
        setPosts(s.map((x) => toCard(x, 'post')));
        setCollections(c);
        setEvents(e.map((x) => toCard(x, 'event')));
      })
      .catch((err) => !cancelled && setLoadError(friendlyError(err)))
      .finally(() => !cancelled && setLoading(false));
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => load(), [load]);
  useEffect(() => onAuthorBlocked(() => setBlockTick((t) => t + 1)), []);

  const visible = (cards) => cards.filter((c) => !isBlockedAuthor(c.author));

  const refreshCollections = () => listCollections().then(setCollections).catch(() => {});

  // ---- Saved items -------------------------------------------------------------------

  const handleUnsave = async (card, e) => {
    e.stopPropagation();
    const setter = card.type === 'piece' ? setPieces : card.type === 'post' ? setPosts : setEvents;
    const index = (card.type === 'piece' ? pieces : card.type === 'post' ? posts : events).findIndex((c) => c.key === card.key);
    setter((prev) => prev.filter((c) => c.key !== card.key));
    try {
      if (card.type === 'event') await setEventSaved(card.id, false);
      else await setSaved(card.type, card.id, false);
    } catch (err) {
      // Put it back where it was.
      setter((prev) => {
        const next = [...prev];
        next.splice(Math.max(0, index), 0, card);
        return next;
      });
      showToast(friendlyError(err));
    }
  };

  const openCard = (card) => {
    // There's no event detail route yet — /event is the events hub.
    if (card.type === 'event') navigate('/event');
    else navigate(contentHref({ id: card.id, type: card.type }));
  };

  const handleAddToCollection = async (collection) => {
    const card = addTarget;
    setAddTarget(null);
    try {
      await addToCollection(collection.id, card.type, card.id);
      showToast(`Added to ${collection.name}`);
      refreshCollections();
    } catch (err) {
      showToast(friendlyError(err));
    }
  };

  // ---- Collections -------------------------------------------------------------------

  const openCollectionView = async (col) => {
    setOpenCollection({ id: col.id, name: col.name, items: null, error: '' });
    try {
      const detail = await getCollection(col.id);
      setOpenCollection({
        id: detail.id,
        name: detail.name,
        items: (detail.items || []).map((x) => toCard(x, x.targetType === 'post' ? 'post' : 'piece')),
        error: '',
      });
    } catch (err) {
      setOpenCollection((cur) => (cur?.id === col.id ? { ...cur, items: [], error: friendlyError(err) } : cur));
    }
  };

  const handleRemoveFromCollection = async (card, e) => {
    e.stopPropagation();
    const col = openCollection;
    const before = col.items;
    setOpenCollection({ ...col, items: before.filter((c) => c.key !== card.key) });
    try {
      await removeFromCollection(col.id, card.type, card.id);
      refreshCollections();
    } catch (err) {
      setOpenCollection((cur) => (cur?.id === col.id ? { ...cur, items: before } : cur));
      showToast(friendlyError(err));
    }
  };

  const handleNameSubmit = async (e) => {
    e.preventDefault();
    const name = nameModal?.value.trim();
    if (!name || nameBusy) return;
    setNameBusy(true);
    setNameError('');
    try {
      if (nameModal.mode === 'create') {
        const created = await createCollection(name);
        setCollections((prev) => [...prev, created]);
        // Started from "Add to collection" → finish that add into the new collection.
        if (nameModal.pendingCard) {
          await addToCollection(created.id, nameModal.pendingCard.type, nameModal.pendingCard.id);
          showToast(`Added to ${created.name}`);
          refreshCollections();
        }
      } else {
        const updated = await renameCollection(openCollection.id, name);
        setOpenCollection((cur) => (cur ? { ...cur, name: updated?.name || name } : cur));
        setCollections((prev) => prev.map((c) => (c.id === openCollection.id ? { ...c, ...updated } : c)));
      }
      setNameModal(null);
    } catch (err) {
      setNameError(friendlyError(err));
    } finally {
      setNameBusy(false);
    }
  };

  const handleDeleteCollection = async () => {
    const col = openCollection;
    setConfirmDelete(false);
    try {
      await deleteCollection(col.id);
      setCollections((prev) => prev.filter((c) => c.id !== col.id));
      setOpenCollection(null);
      showToast('Collection deleted');
    } catch (err) {
      showToast(friendlyError(err));
    }
  };

  // ---- Render ------------------------------------------------------------------------

  const allSaved = [...visible(pieces), ...visible(posts), ...visible(events)];
  const filteredItems =
    activeTab === 'pieces'
      ? visible(pieces)
      : activeTab === 'scenes'
        ? visible(posts)
        : activeTab === 'events'
          ? visible(events)
          : allSaved;

  const renderCard = (card, { onRemove, removeTitle, removeIcon, canCollect }) => (
    <div key={card.key} className="saved-card" onClick={() => openCard(card)}>
      {card.src ? (
        <img src={card.src} alt={card.title} draggable={false} />
      ) : card.videoSrc ? (
        <video src={card.videoSrc} muted playsInline preload="metadata" />
      ) : null}
      <span className="saved-card-badge">{badgeFor(card.type)}</span>
      {canCollect && (
        <button
          type="button"
          className="saved-card-unsave saved-card-collect"
          title="Add to collection"
          aria-label="Add to collection"
          onClick={(e) => {
            e.stopPropagation();
            setAddTarget(card);
          }}
        >
          <FolderPlus size={14} />
        </button>
      )}
      <button type="button" className="saved-card-unsave" title={removeTitle} aria-label={removeTitle} onClick={(e) => onRemove(card, e)}>
        {removeIcon}
      </button>
    </div>
  );

  const renderEmpty = (title, sub) => (
    <div className="saved-empty">
      <Bookmark size={36} className="saved-empty-icon" />
      <p className="saved-empty-title">{title}</p>
      <p className="saved-empty-sub">{sub}</p>
    </div>
  );

  const collectionView = openCollection && (
    <>
      <div className="saved-header">
        <div className="saved-header-lead">
          <button type="button" className="saved-icon-btn" aria-label="Back to saved" onClick={() => setOpenCollection(null)}>
            <ChevronLeft size={20} />
          </button>
          <h1 className="saved-title">{openCollection.name}</h1>
        </div>
        <button type="button" className="saved-icon-btn" aria-label="Collection options" onClick={() => setCollectionMenuOpen(true)}>
          <MoreHorizontal size={20} />
        </button>
      </div>
      {openCollection.items === null ? (
        <p className="saved-status">Loading…</p>
      ) : openCollection.error ? (
        <p className="saved-status saved-status--error">{openCollection.error}</p>
      ) : visible(openCollection.items).length === 0 ? (
        renderEmpty('This collection is empty', 'Add saved pieces and scenes to it from your Saved grid')
      ) : (
        <div className="saved-grid">
          {visible(openCollection.items).map((card) =>
            renderCard(card, {
              onRemove: handleRemoveFromCollection,
              removeTitle: 'Remove from collection',
              removeIcon: <X size={14} />,
            }),
          )}
        </div>
      )}
    </>
  );

  return (
    <div className="saved-page">
      <div style={{ display: 'flex', gap: 48, maxWidth: railLabeled ? 935 + 320 + 48 : 935, margin: '0 auto' }}>
      <div className="saved-inner" style={{ margin: 0, flex: 1, minWidth: 0 }}>
        {openCollection ? (
          collectionView
        ) : (
          <>
            <div className="saved-header">
              <h1 className="saved-title">Saved</h1>
              <button
                type="button"
                className="saved-create-btn"
                onClick={() => {
                  setNameError('');
                  setNameModal({ mode: 'create', value: '' });
                }}
              >
                <FolderPlus size={16} />
                <span>New collection</span>
              </button>
            </div>

            {/* Filter Tabs */}
            <div className="saved-tabs" role="tablist">
              {TABS.map((tabId) => (
                <button
                  key={tabId}
                  type="button"
                  role="tab"
                  aria-selected={activeTab === tabId}
                  className={`saved-tab${activeTab === tabId ? ' is-active' : ''}`}
                  onClick={() => setActiveTab(tabId)}
                >
                  {tabId.charAt(0).toUpperCase() + tabId.slice(1)}
                </button>
              ))}
            </div>

            {loading ? (
              <p className="saved-status">Loading…</p>
            ) : loadError ? (
              <div className="saved-empty">
                <p className="saved-empty-title">Couldn’t load your saved items</p>
                <p className="saved-empty-sub">{loadError}</p>
                <button type="button" className="saved-create-btn saved-retry-btn" onClick={load}>
                  Try again
                </button>
              </div>
            ) : (
              <>
                {/* Collections Section */}
                {collections.length > 0 && activeTab === 'all' && (
                  <div className="saved-collections-section">
                    <h2 className="saved-section-label">Collections</h2>
                    <div className="saved-collections-grid">
                      {collections.map((col) => (
                        <button type="button" key={col.id} className="saved-collection-card" onClick={() => openCollectionView(col)}>
                          {col.cover?.mediaUrl ? (
                            isVideoUrl(col.cover.mediaUrl) ? (
                              <video className="saved-collection-cover" src={col.cover.mediaUrl} muted playsInline preload="metadata" />
                            ) : (
                              <img className="saved-collection-cover" src={col.cover.mediaUrl} alt="" />
                            )
                          ) : (
                            <div style={{ width: '100%', height: '100%', background: '#ded9d1' }} />
                          )}
                          <div className="saved-collection-overlay">
                            <p className="saved-collection-name">{col.name}</p>
                            <p className="saved-collection-count">
                              {col.itemCount || 0} {col.itemCount === 1 ? 'item' : 'items'}
                            </p>
                          </div>
                        </button>
                      ))}
                    </div>
                  </div>
                )}

                {/* Items Grid */}
                {filteredItems.length === 0 ? (
                  renderEmpty('No saved items', 'Artwork, scenes, and events you save will appear here')
                ) : (
                  <div className="saved-grid">
                    {filteredItems.map((card) =>
                      renderCard(card, {
                        onRemove: handleUnsave,
                        removeTitle: 'Remove from saved',
                        removeIcon: <Trash2 size={14} />,
                        canCollect: card.type !== 'event',
                      }),
                    )}
                  </div>
                )}
              </>
            )}
          </>
        )}
      </div>
      {railLabeled && <InboxRail />}
      </div>

      {/* Collection options */}
      {collectionMenuOpen && openCollection && (
        <ActionSheet title={openCollection.name} onClose={() => setCollectionMenuOpen(false)}>
          <SheetItem
            icon={<Pencil size={18} />}
            onClick={() => {
              setCollectionMenuOpen(false);
              setNameError('');
              setNameModal({ mode: 'rename', value: openCollection.name });
            }}
          >
            Rename collection
          </SheetItem>
          <SheetItem
            danger
            icon={<Trash2 size={18} />}
            onClick={() => {
              setCollectionMenuOpen(false);
              setConfirmDelete(true);
            }}
          >
            Delete collection
          </SheetItem>
        </ActionSheet>
      )}

      {/* Add to collection */}
      {addTarget && (
        <ActionSheet title="Add to collection" subtitle={addTarget.title} onClose={() => setAddTarget(null)}>
          {collections.map((col) => (
            <SheetItem key={col.id} icon={<Folder size={18} />} onClick={() => handleAddToCollection(col)}>
              {col.name}
            </SheetItem>
          ))}
          <SheetItem
            icon={<FolderPlus size={18} />}
            onClick={() => {
              const card = addTarget;
              setAddTarget(null);
              setNameError('');
              setNameModal({ mode: 'create', value: '', pendingCard: card });
            }}
          >
            New collection
          </SheetItem>
        </ActionSheet>
      )}

      {/* New / rename collection modal */}
      {nameModal && (
        <div className="saved-modal-overlay" onClick={() => !nameBusy && setNameModal(null)}>
          <div className="saved-modal" onClick={(e) => e.stopPropagation()}>
            <h3 className="saved-modal-title">{nameModal.mode === 'create' ? 'New Collection' : 'Rename Collection'}</h3>
            <form onSubmit={handleNameSubmit}>
              <input
                type="text"
                className="saved-modal-input"
                placeholder="Collection name"
                maxLength={120}
                value={nameModal.value}
                onChange={(e) => setNameModal({ ...nameModal, value: e.target.value })}
                autoFocus
              />
              {nameError && <p className="saved-modal-error">{nameError}</p>}
              <div className="saved-modal-actions">
                <button type="button" className="saved-modal-btn saved-modal-btn-cancel" onClick={() => setNameModal(null)} disabled={nameBusy}>
                  Cancel
                </button>
                <button type="submit" className="saved-modal-btn saved-modal-btn-create" disabled={nameBusy || !nameModal.value.trim()}>
                  {nameModal.mode === 'create' ? 'Create' : 'Save'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Delete confirmation */}
      {confirmDelete && openCollection && (
        <div className="saved-modal-overlay" onClick={() => setConfirmDelete(false)}>
          <div className="saved-modal" onClick={(e) => e.stopPropagation()}>
            <h3 className="saved-modal-title">Delete “{openCollection.name}”?</h3>
            <p className="saved-modal-text">The items stay in your Saved list — only the collection is removed.</p>
            <div className="saved-modal-actions">
              <button type="button" className="saved-modal-btn saved-modal-btn-cancel" onClick={() => setConfirmDelete(false)}>
                Cancel
              </button>
              <button type="button" className="saved-modal-btn saved-modal-btn-danger" onClick={handleDeleteCollection}>
                Delete
              </button>
            </div>
          </div>
        </div>
      )}

      {toast}
    </div>
  );
}
