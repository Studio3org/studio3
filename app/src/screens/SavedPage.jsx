import React, { useCallback, useEffect, useState } from 'react';
import { ChevronLeft, Folder, MoreHorizontal, Plus } from 'lucide-react';
import { TileGrid } from '../components/content/FeedCard';
import { StateMessage, GuestPrompt } from '../components/common/StateMessage';
import { SafeArea } from '../components/layout/SafeArea';
import { useSession } from '../lib/session';
import { friendlyError } from '../lib/social';
import {
  fetchSaved,
  fetchCollections,
  fetchCollection,
  createCollection,
  renameCollection,
  deleteCollection,
  useVisibleItems,
} from '../lib/feedApi';

const headerStyle = {
  position: 'sticky',
  top: 0,
  zIndex: 10,
  background: 'rgba(255,255,255,0.72)',
  backdropFilter: 'blur(16px)',
  padding: '12px 16px',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'space-between',
  gap: 8,
  borderBottom: '1px solid var(--slate-100)',
  marginLeft: -16,
  marginRight: -16,
};

const tabStyle = (active) => ({
  padding: '8px 20px',
  borderRadius: 9999,
  fontSize: 14,
  fontWeight: 500,
  background: active ? 'var(--slate-900)' : 'transparent',
  color: active ? 'var(--white)' : 'var(--slate-600)',
  boxShadow: active ? '0 2px 8px rgba(15,23,42,0.1)' : 'none',
});

const TABS = [
  ['pieces', 'Pieces'],
  ['scenes', 'Scenes'],
  ['collections', 'Collections'],
];

/// Loads a plain-array endpoint once per mount; `reload` refetches.
function useLoader(load) {
  const [state, setState] = useState({ loading: true, data: null, error: null });
  const reload = useCallback(async () => {
    setState((s) => ({ ...s, loading: true, error: null }));
    try {
      setState({ loading: false, data: await load(), error: null });
    } catch (e) {
      setState({ loading: false, data: null, error: e });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  useEffect(() => {
    reload();
  }, [reload]);
  return { ...state, reload };
}

export function SavedPage() {
  const { loggedIn } = useSession();
  const [tab, setTab] = useState('pieces');
  const [openCollection, setOpenCollection] = useState(null);

  if (!loggedIn) {
    return (
      <SafeArea>
        <GuestPrompt
          title="Your saved work"
          message="Log in to save pieces and scenes and organize them into collections."
          next="/saved"
        />
      </SafeArea>
    );
  }

  if (openCollection) {
    return (
      <SafeArea style={{ paddingTop: 0 }}>
        <CollectionDetail id={openCollection} onBack={() => setOpenCollection(null)} />
      </SafeArea>
    );
  }

  return (
    <SafeArea style={{ paddingTop: 0 }}>
      <header style={headerStyle}>
        <h1 style={{ fontSize: 20, fontWeight: 700, color: 'var(--slate-900)' }}>Saved</h1>
      </header>
      <div style={{ display: 'flex', gap: 8, margin: '12px 0 16px' }}>
        {TABS.map(([key, label]) => (
          <button key={key} style={tabStyle(tab === key)} onClick={() => setTab(key)}>{label}</button>
        ))}
      </div>
      {tab === 'pieces' && <SavedItems key="piece" kind="piece" />}
      {tab === 'scenes' && <SavedItems key="post" kind="post" />}
      {tab === 'collections' && <CollectionsList onOpen={setOpenCollection} />}
    </SafeArea>
  );
}

function SavedItems({ kind }) {
  const { loading, data, error, reload } = useLoader(() => fetchSaved(kind));
  const items = useVisibleItems(data ?? []);
  if (loading) return <StateMessage>Loading…</StateMessage>;
  if (error) return <StateMessage action="Try again" onAction={reload}>{friendlyError(error)}</StateMessage>;
  if (items.length === 0) {
    return <StateMessage>{kind === 'post' ? 'Scenes you save will appear here.' : 'Pieces you save will appear here.'}</StateMessage>;
  }
  return <TileGrid items={items} />;
}

function CollectionsList({ onOpen }) {
  const { loading, data, error, reload } = useLoader(fetchCollections);
  const [actionError, setActionError] = useState(null);

  const create = async () => {
    const name = window.prompt('Name your collection')?.trim();
    if (!name) return;
    setActionError(null);
    try {
      await createCollection(name);
      reload();
    } catch (e) {
      setActionError(friendlyError(e));
    }
  };

  if (loading) return <StateMessage>Loading…</StateMessage>;
  if (error) return <StateMessage action="Try again" onAction={reload}>{friendlyError(error)}</StateMessage>;

  const collections = data ?? [];
  return (
    <>
      <button
        type="button"
        onClick={create}
        style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '10px 16px', borderRadius: 9999, border: '1.5px solid var(--slate-200)', background: 'var(--white)', fontSize: 14, fontWeight: 500, color: 'var(--slate-900)', marginBottom: 16 }}
      >
        <Plus size={16} /> New collection
      </button>
      {actionError && <p style={{ fontSize: 13, color: '#E05252', marginBottom: 12 }}>{actionError}</p>}
      {collections.length === 0 ? (
        <StateMessage>No collections yet. Create one to group the work you save.</StateMessage>
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          {collections.map((c) => (
            <button
              key={c.id}
              type="button"
              onClick={() => onOpen(c.id)}
              style={{ display: 'block', textAlign: 'left', borderRadius: 14, overflow: 'hidden', background: 'var(--white)', boxShadow: 'var(--shadow-card)' }}
            >
              <div style={{ aspectRatio: '1', background: 'var(--slate-100)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--slate-400)' }}>
                {c.cover?.mediaUrl ? (
                  <img src={c.cover.mediaUrl} alt="" loading="lazy" style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} />
                ) : (
                  <Folder size={28} strokeWidth={1.5} />
                )}
              </div>
              <div style={{ padding: '8px 10px' }}>
                <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--slate-900)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{c.name}</div>
                <div style={{ fontSize: 11, color: 'var(--slate-500)', marginTop: 2 }}>
                  {c.itemCount ?? 0} {c.itemCount === 1 ? 'item' : 'items'}
                </div>
              </div>
            </button>
          ))}
        </div>
      )}
    </>
  );
}

function CollectionDetail({ id, onBack }) {
  const { loading, data, error, reload } = useLoader(() => fetchCollection(id));
  const items = useVisibleItems(data?.items ?? []);
  const [menuOpen, setMenuOpen] = useState(false);
  const [actionError, setActionError] = useState(null);

  const rename = async () => {
    setMenuOpen(false);
    const name = window.prompt('Rename collection', data?.name ?? '')?.trim();
    if (!name || name === data?.name) return;
    setActionError(null);
    try {
      await renameCollection(id, name);
      reload();
    } catch (e) {
      setActionError(friendlyError(e));
    }
  };

  const remove = async () => {
    setMenuOpen(false);
    if (!window.confirm(`Delete "${data?.name ?? 'this collection'}"? Saved items stay saved.`)) return;
    setActionError(null);
    try {
      await deleteCollection(id);
      onBack();
    } catch (e) {
      setActionError(friendlyError(e));
    }
  };

  return (
    <>
      <header style={headerStyle}>
        <button type="button" aria-label="Back" onClick={onBack} style={{ display: 'flex', color: 'var(--slate-700)', padding: 4 }}>
          <ChevronLeft size={24} />
        </button>
        <h1 style={{ flex: 1, minWidth: 0, fontSize: 18, fontWeight: 700, color: 'var(--slate-900)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {data?.name ?? 'Collection'}
        </h1>
        {data && (
          <div style={{ position: 'relative' }}>
            <button type="button" aria-label="Collection options" onClick={() => setMenuOpen((o) => !o)} style={{ display: 'flex', color: 'var(--slate-700)', padding: 4 }}>
              <MoreHorizontal size={22} />
            </button>
            {menuOpen && (
              <>
                <div style={{ position: 'fixed', inset: 0, zIndex: 20 }} onClick={() => setMenuOpen(false)} />
                <div className="glass-light" style={{ position: 'absolute', top: '100%', right: 0, marginTop: 8, minWidth: 160, padding: 6, boxShadow: 'var(--shadow-float)', zIndex: 21 }}>
                  <MenuButton label="Rename" onClick={rename} />
                  <MenuButton label="Delete" onClick={remove} danger />
                </div>
              </>
            )}
          </div>
        )}
      </header>
      <div style={{ marginTop: 16 }}>
        {actionError && <p style={{ fontSize: 13, color: '#E05252', marginBottom: 12 }}>{actionError}</p>}
        {loading ? (
          <StateMessage>Loading…</StateMessage>
        ) : error ? (
          <StateMessage action="Try again" onAction={reload}>{friendlyError(error)}</StateMessage>
        ) : items.length === 0 ? (
          <StateMessage>This collection is empty.</StateMessage>
        ) : (
          <TileGrid items={items} />
        )}
      </div>
    </>
  );
}

function MenuButton({ label, onClick, danger }) {
  return (
    <button
      type="button"
      onClick={onClick}
      style={{ display: 'block', width: '100%', padding: '10px 12px', borderRadius: 'var(--radius-md)', fontSize: 14, fontWeight: 500, textAlign: 'left', color: danger ? '#E05252' : 'var(--slate-900)' }}
    >
      {label}
    </button>
  );
}
