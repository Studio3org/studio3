import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { apiFetch } from '../services/apiClient';
import { Bookmark, Plus, Trash2, FolderPlus } from 'lucide-react';
import './SavedPage.css';

const DEMO_SAVED_ITEMS = [
  { id: 'p1', type: 'piece', title: 'Serenade in Ochre', src: '/profile/piece-r1.png', ratio: '1/1' },
  { id: 'p2', type: 'piece', title: 'Echoes of Summer', src: '/profile/piece-r2.png', ratio: '181/113' },
  { id: 's1', type: 'scene', title: 'Studio Practice', src: '/profile/piece-l1.png', ratio: '181/270' },
  { id: 'e1', type: 'event', title: 'Contemporary Art Fair', src: '/profile/piece-l2.png', ratio: '1/1' },
];

export function SavedPage() {
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState('all');
  const [collections, setCollections] = useState([]);
  const [savedItems, setSavedItems] = useState(DEMO_SAVED_ITEMS);
  const [loading, setLoading] = useState(false);
  const [createModalOpen, setCreateModalOpen] = useState(false);
  const [newCollectionName, setNewCollectionName] = useState('');

  useEffect(() => {
    let cancelled = false;
    setLoading(true);

    // Fetch user collections
    apiFetch('/api/collections', { auth: true })
      .then((data) => {
        if (!cancelled && Array.isArray(data)) setCollections(data);
      })
      .catch(() => {})
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
  }, []);

  const handleCreateCollection = async (e) => {
    e.preventDefault();
    if (!newCollectionName.trim()) return;
    try {
      const created = await apiFetch('/api/collections', {
        method: 'POST',
        auth: true,
        body: { name: newCollectionName.trim() },
      });
      if (created) {
        setCollections((prev) => [...prev, created]);
      }
    } catch {
      // Fallback local collection push
      setCollections((prev) => [...prev, { id: `c_${Date.now()}`, name: newCollectionName.trim(), itemsCount: 0 }]);
    } finally {
      setNewCollectionName('');
      setCreateModalOpen(false);
    }
  };

  const handleUnsave = (id, e) => {
    e.stopPropagation();
    setSavedItems((prev) => prev.filter((item) => item.id !== id));
  };

  const filteredItems = savedItems.filter((item) => {
    if (activeTab === 'all') return true;
    if (activeTab === 'pieces') return item.type === 'piece';
    if (activeTab === 'scenes') return item.type === 'scene';
    if (activeTab === 'events') return item.type === 'event';
    return true;
  });

  return (
    <div className="saved-page">
      <div className="saved-inner">
        <div className="saved-header">
          <h1 className="saved-title">Saved</h1>
          <button
            type="button"
            className="saved-create-btn"
            onClick={() => setCreateModalOpen(true)}
          >
            <FolderPlus size={16} />
            <span>New collection</span>
          </button>
        </div>

        {/* Filter Tabs */}
        <div className="saved-tabs" role="tablist">
          {['all', 'pieces', 'scenes', 'events'].map((tabId) => (
            <button
              key={tabId}
              type="button"
              className={`saved-tab${activeTab === tabId ? ' is-active' : ''}`}
              onClick={() => setActiveTab(tabId)}
            >
              {tabId.charAt(0).toUpperCase() + tabId.slice(1)}
            </button>
          ))}
        </div>

        {/* Collections Section */}
        {collections.length > 0 && activeTab === 'all' && (
          <div className="saved-collections-section">
            <h2 className="saved-section-label">Collections</h2>
            <div className="saved-collections-grid">
              {collections.map((col) => (
                <div key={col.id} className="saved-collection-card">
                  {col.coverUrl ? (
                    <img className="saved-collection-cover" src={col.coverUrl} alt="" />
                  ) : (
                    <div style={{ width: '100%', height: '100%', background: '#ded9d1' }} />
                  )}
                  <div className="saved-collection-overlay">
                    <p className="saved-collection-name">{col.name}</p>
                    <p className="saved-collection-count">{col.itemsCount || 0} items</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Items Grid */}
        {filteredItems.length === 0 ? (
          <div className="saved-empty">
            <Bookmark size={36} className="saved-empty-icon" />
            <p className="saved-empty-title">No saved items</p>
            <p className="saved-empty-sub">
              Artwork, scenes, and events you save will appear here
            </p>
          </div>
        ) : (
          <div className="saved-grid">
            {filteredItems.map((item) => (
              <div
                key={item.id}
                className="saved-card"
                onClick={() => {
                  if (item.type === 'piece') navigate(`/piece/${item.id}`);
                  else if (item.type === 'event') navigate('/event');
                  else navigate('/post');
                }}
              >
                <img src={item.src} alt={item.title} draggable={false} />
                <span className="saved-card-badge">{item.type}</span>
                <button
                  type="button"
                  className="saved-card-unsave"
                  title="Remove from saved"
                  onClick={(e) => handleUnsave(item.id, e)}
                >
                  <Trash2 size={14} />
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* New Collection Modal */}
      {createModalOpen && (
        <div className="saved-modal-overlay" onClick={() => setCreateModalOpen(false)}>
          <div className="saved-modal" onClick={(e) => e.stopPropagation()}>
            <h3 className="saved-modal-title">New Collection</h3>
            <form onSubmit={handleCreateCollection}>
              <input
                type="text"
                className="saved-modal-input"
                placeholder="Collection name"
                value={newCollectionName}
                onChange={(e) => setNewCollectionName(e.target.value)}
                autoFocus
              />
              <div className="saved-modal-actions">
                <button
                  type="button"
                  className="saved-modal-btn saved-modal-btn-cancel"
                  onClick={() => setCreateModalOpen(false)}
                >
                  Cancel
                </button>
                <button type="submit" className="saved-modal-btn saved-modal-btn-create">
                  Create
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
