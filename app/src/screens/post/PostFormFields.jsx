import React, { useState } from 'react';
import { AUCTION_DURATIONS } from './usePostForm';
import {
  LocationIcon,
  MediumIcon,
  StyleIcon,
  MaterialsIcon,
  SeriesIcon,
  ScenesIcon,
  AiToolsIcon,
  ChevronRightIcon,
} from '../../components/icons/PostIcons';
import { OptionPickerOverlay } from './PostOptionPickers';
import { MEDIUM_OPTIONS, STYLE_OPTIONS, MATERIAL_OPTIONS, LOCATION_OPTIONS } from './PostPickerOptions';

export function TabBar({ form }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'center', gap: 24, borderBottom: '1px solid var(--cream-title-hairline)', paddingBottom: 10 }}>
      {form.TABS.map((t, i) => (
        <button
          key={t}
          onClick={() => form.goTab(i)}
          style={{
            fontFamily: 'var(--font-inter)',
            fontSize: 13,
            fontWeight: form.tab === t ? 500 : 400,
            color: i > form.unlocked ? 'var(--cream-text-secondary)' : form.tab === t ? 'var(--cream-text)' : 'var(--cream-text-secondary)',
            opacity: i > form.unlocked ? 0.4 : 1,
          }}
        >
          {t}
        </button>
      ))}
    </div>
  );
}

export function AvailabilityTab({ form }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '4px 0' }}>
        <span style={{ fontFamily: 'var(--font-inter)', fontSize: 15, fontWeight: 500, color: 'var(--cream-text)' }}>List for sale</span>
        <Toggle checked={form.forSale} onChange={form.setForSale} />
      </div>

      {form.forSale && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16, marginTop: 4 }}>
          <div style={{ display: 'flex', gap: 8 }}>
            {['fixed', 'auction'].map((lt) => (
              <button
                key={lt}
                onClick={() => form.setListingType(lt)}
                style={{
                  flex: 1,
                  padding: '12px',
                  borderRadius: 10,
                  border: `1px solid ${form.listingType === lt ? 'var(--cream-text)' : 'rgba(35,31,27,0.15)'}`,
                  background: form.listingType === lt ? 'rgba(35,31,27,0.06)' : 'transparent',
                  fontFamily: 'var(--font-inter)',
                  fontSize: 13,
                  fontWeight: 500,
                  color: 'var(--cream-text)',
                  textTransform: 'capitalize',
                }}
              >
                {lt === 'fixed' ? 'Fixed price' : 'Auction'}
              </button>
            ))}
          </div>

          <PillField
            placeholder={form.listingType === 'auction' ? 'Starting bid ($)' : 'Price ($)'}
            value={form.price}
            onChange={form.setPrice}
            type="number"
          />

          {form.listingType === 'auction' && (
            <div>
              <div style={{ fontFamily: 'var(--font-inter)', fontSize: 12, color: 'var(--cream-text-secondary)', marginBottom: 8 }}>
                Auction Duration
              </div>
              <div style={{ display: 'flex', gap: 8 }}>
                {AUCTION_DURATIONS.map((days) => (
                  <button
                    key={days}
                    onClick={() => form.setAuctionDurationDays(days)}
                    style={{
                      flex: 1,
                      padding: '10px',
                      borderRadius: 8,
                      border: `1px solid ${form.auctionDurationDays === days ? 'var(--cream-text)' : 'rgba(35,31,27,0.15)'}`,
                      background: form.auctionDurationDays === days ? 'rgba(35,31,27,0.06)' : 'transparent',
                      fontFamily: 'var(--font-inter)',
                      fontSize: 13,
                      fontWeight: 500,
                      color: 'var(--cream-text)',
                    }}
                  >
                    {days} days
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export function DetailsTab({ type, form }) {
  const [activePicker, setActivePicker] = useState(null);
  const [additionalOpen, setAdditionalOpen] = useState(false);

  // Helper for option labels
  const getLocationName = () => {
    const loc = LOCATION_OPTIONS.find((l) => l.id === form.location);
    return loc ? loc.name : form.location || null;
  };

  const getMediumName = () => {
    const m = MEDIUM_OPTIONS.find((opt) => opt.id === form.medium);
    return m ? m.name : form.medium || null;
  };

  const getStyleTrailing = () => {
    if (!form.styles || form.styles.length === 0) return null;
    return form.styles.map((id) => STYLE_OPTIONS.find((s) => s.id === id)?.name || id).join(', ');
  };

  const getMaterialsTrailing = () => {
    if (!form.materials || form.materials.length === 0) return null;
    return `${form.materials.length} added`;
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      {type === 'piece' ? (
        <>
          <PillField placeholder="Title" value={form.title} onChange={form.setTitle} />
          <textarea
            placeholder="Story / caption"
            value={form.caption}
            onChange={(e) => form.setCaption(e.target.value)}
            style={{
              minHeight: 88,
              borderRadius: 14,
              background: 'var(--cream-bg-detail)',
              border: '1px solid rgba(35,31,27,0.15)',
              padding: 14,
              fontFamily: 'var(--font-inter)',
              fontSize: 14,
              color: 'var(--cream-text)',
              resize: 'vertical',
              outline: 'none',
            }}
          />

          <div style={{ display: 'flex', flexDirection: 'column', gap: 2, borderRadius: 14, overflow: 'hidden', background: 'var(--cream-bg-detail)' }}>
            <MetadataOptionRow
              icon={<LocationIcon size={16} color="var(--cream-text)" />}
              label="Location"
              trailing={getLocationName()}
              onClick={() => setActivePicker('location')}
            />
            <Divider />

            {/* Dimensions Pill Input */}
            <div style={{ padding: '10px 14px', display: 'flex', alignItems: 'center', gap: 10 }}>
              <span style={{ fontFamily: 'var(--font-inter)', fontSize: 13, color: 'var(--cream-text-secondary)', flexShrink: 0 }}>Dimensions</span>
              <input
                type="number"
                placeholder="W"
                value={form.dimWidth}
                onChange={(e) => form.setDimWidth(e.target.value)}
                style={{
                  width: 56,
                  height: 32,
                  borderRadius: 8,
                  border: '1px solid rgba(35,31,27,0.15)',
                  background: '#fff',
                  textAlign: 'center',
                  fontFamily: 'var(--font-inter)',
                  fontSize: 13,
                }}
              />
              <span style={{ fontSize: 12, color: 'var(--cream-text-secondary)' }}>×</span>
              <input
                type="number"
                placeholder="H"
                value={form.dimHeight}
                onChange={(e) => form.setDimHeight(e.target.value)}
                style={{
                  width: 56,
                  height: 32,
                  borderRadius: 8,
                  border: '1px solid rgba(35,31,27,0.15)',
                  background: '#fff',
                  textAlign: 'center',
                  fontFamily: 'var(--font-inter)',
                  fontSize: 13,
                }}
              />
              <div style={{ display: 'flex', borderRadius: 6, overflow: 'hidden', border: '1px solid rgba(35,31,27,0.15)' }}>
                {['in', 'cm'].map((u) => (
                  <button
                    key={u}
                    onClick={() => form.setDimUnit(u)}
                    style={{
                      padding: '4px 8px',
                      fontSize: 11,
                      fontFamily: 'var(--font-inter)',
                      background: form.dimUnit === u ? 'var(--cream-text)' : '#fff',
                      color: form.dimUnit === u ? '#fff' : 'var(--cream-text)',
                    }}
                  >
                    {u}
                  </button>
                ))}
              </div>
            </div>
            <Divider />

            <MetadataOptionRow
              icon={<MediumIcon size={16} color="var(--cream-text)" />}
              label={form.forSale ? 'Medium (required)' : 'Medium'}
              trailing={getMediumName()}
              onClick={() => setActivePicker('medium')}
            />
            <Divider />

            <MetadataOptionRow
              icon={<StyleIcon size={16} color="var(--cream-text)" />}
              label="Style"
              trailing={getStyleTrailing()}
              countBadge={form.styles?.length}
              onClick={() => setActivePicker('style')}
            />
            <Divider />

            <MetadataOptionRow
              icon={<MaterialsIcon size={16} color="var(--cream-text)" />}
              label="Materials"
              trailing={getMaterialsTrailing()}
              countBadge={form.materials?.length}
              onClick={() => setActivePicker('materials')}
            />
            <Divider />

            <MetadataOptionRow
              icon={<SeriesIcon size={16} color="var(--cream-text)" />}
              label="Series"
              trailing={form.series || null}
              onClick={() => setActivePicker('series')}
            />
            <Divider />

            <MetadataOptionRow
              icon={<ScenesIcon size={16} color="var(--cream-text)" />}
              label="Related Scenes"
              trailing={form.relatedScenes?.length ? `${form.relatedScenes.length} linked` : null}
              onClick={() => setActivePicker('scenes')}
            />
            <Divider />

            <MetadataOptionRow
              icon={<AiToolsIcon size={16} color="var(--cream-text)" />}
              label="Additional details"
              trailing={additionalOpen ? 'Hide' : 'Show'}
              onClick={() => setAdditionalOpen(!additionalOpen)}
            />
          </div>

          {/* Additional details expandable section */}
          {additionalOpen && (
            <div
              style={{
                display: 'flex',
                flexDirection: 'column',
                gap: 12,
                padding: 14,
                borderRadius: 14,
                background: 'var(--cream-bg-detail)',
                border: '1px solid rgba(35,31,27,0.12)',
              }}
            >
              <PillField placeholder="Year created (e.g. 2026)" value={form.yearCreated} onChange={form.setYearCreated} />
              <PillField placeholder="Framing (e.g. Framed, Ready to hang)" value={form.framing} onChange={form.setFraming} />
              <PillField placeholder="Handling / Care instructions" value={form.handling} onChange={form.setHandling} />
              <PillField placeholder="Shipping region (e.g. Worldwide, US only)" value={form.shippingRegion} onChange={form.setShippingRegion} />
            </div>
          )}
        </>
      ) : (
        /* SCENE Flow Details */
        <>
          <textarea
            placeholder="Write a caption..."
            value={form.caption}
            onChange={(e) => form.setCaption(e.target.value)}
            style={{
              minHeight: 110,
              borderRadius: 14,
              background: 'var(--cream-bg-detail)',
              border: '1px solid rgba(35,31,27,0.15)',
              padding: 14,
              fontFamily: 'var(--font-inter)',
              fontSize: 14,
              color: 'var(--cream-text)',
              resize: 'vertical',
              outline: 'none',
            }}
          />
          <div style={{ display: 'flex', flexDirection: 'column', borderRadius: 14, overflow: 'hidden', background: 'var(--cream-bg-detail)' }}>
            <MetadataOptionRow
              icon={<LocationIcon size={16} color="var(--cream-text)" />}
              label="Location"
              trailing={getLocationName()}
              onClick={() => setActivePicker('location')}
            />
            <Divider />
            <MetadataOptionRow
              icon={<ScenesIcon size={16} color="var(--cream-text)" />}
              label="Link to a Piece"
              trailing={form.linkedPiece ? 'Linked' : null}
              onClick={() => setActivePicker('linkPiece')}
            />
          </div>
        </>
      )}

      {/* Option Pickers Dialog Overlays */}
      {activePicker === 'location' && (
        <OptionPickerOverlay
          title="Location"
          subtitle="Select location"
          searchHint="Search cities"
          options={LOCATION_OPTIONS}
          selectedIds={form.location ? [form.location] : []}
          onClose={() => setActivePicker(null)}
          onSave={(ids) => form.setLocation(ids[0] || '')}
        />
      )}

      {activePicker === 'medium' && (
        <OptionPickerOverlay
          title="Medium"
          subtitle="Choose primary medium"
          searchHint="Search mediums"
          options={MEDIUM_OPTIONS}
          selectedIds={form.medium ? [form.medium] : []}
          onClose={() => setActivePicker(null)}
          onSave={(ids) => form.setMedium(ids[0] || '')}
        />
      )}

      {activePicker === 'style' && (
        <OptionPickerOverlay
          title="Style"
          subtitle="Select up to 3 styles"
          searchHint="Search styles"
          options={STYLE_OPTIONS}
          selectedIds={form.styles}
          isMulti
          maxSelections={3}
          onClose={() => setActivePicker(null)}
          onSave={(ids) => form.setStyles(ids)}
        />
      )}

      {activePicker === 'materials' && (
        <OptionPickerOverlay
          title="Materials"
          subtitle="Choose materials used"
          searchHint="Search materials"
          options={MATERIAL_OPTIONS}
          selectedIds={form.materials}
          isMulti
          onClose={() => setActivePicker(null)}
          onSave={(ids) => form.setMaterials(ids)}
        />
      )}

      {activePicker === 'series' && (
        <OptionPickerOverlay
          title="Series"
          subtitle="Select series"
          searchHint="Search series"
          options={[
            { id: 'series_1', name: 'Studio Collection 2026' },
            { id: 'series_2', name: 'Abstract Explorations' },
            { id: 'series_3', name: 'Urban Landscapes' },
          ]}
          selectedIds={form.series ? [form.series] : []}
          onClose={() => setActivePicker(null)}
          onSave={(ids) => form.setSeries(ids[0] || '')}
        />
      )}
    </div>
  );
}

export function ReviewTab({ type, form }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
      {form.media.items.length > 0 && (
        <div style={{ display: 'flex', gap: 6, marginBottom: 8, overflowX: 'auto', paddingBottom: 4 }}>
          {form.media.items.map((item, i) => (
            <div key={item.id} style={{ position: 'relative', width: 54, height: 54, borderRadius: 8, overflow: 'hidden', flexShrink: 0 }}>
              {item.mediaType === 'video' ? (
                <video src={item.previewUrl} style={{ width: '100%', height: '100%', objectFit: 'cover' }} muted />
              ) : (
                <img src={item.previewUrl} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
              )}
              {i === 0 && (
                <span
                  style={{
                    position: 'absolute',
                    inset: 'auto 0 0 0',
                    textAlign: 'center',
                    background: 'rgba(35,31,27,0.75)',
                    color: '#fff',
                    fontSize: 9,
                    fontWeight: 500,
                    fontFamily: 'var(--font-inter)',
                    padding: '2px 0',
                  }}
                >
                  Cover
                </span>
              )}
            </div>
          ))}
        </div>
      )}

      {type === 'piece' && <ReviewRow label="Title" value={form.title || 'Untitled'} />}
      <ReviewRow label="Story / Caption" value={form.caption || '—'} />
      {form.location && <ReviewRow label="Location" value={form.location} />}
      {type === 'piece' && <ReviewRow label="For sale" value={form.forSale ? `Yes (${form.listingType === 'auction' ? 'Auction' : 'Fixed price'})` : 'No'} />}
      {type === 'piece' && form.forSale && <ReviewRow label="Price" value={form.price ? `$${form.price}` : '—'} />}
      {type === 'piece' && form.medium && <ReviewRow label="Medium" value={form.medium} />}
      {type === 'piece' && form.dimensionsStr && <ReviewRow label="Dimensions" value={form.dimensionsStr} />}
      {type === 'piece' && form.materials?.length > 0 && <ReviewRow label="Materials" value={`${form.materials.length} selected`} />}
      {type === 'piece' && form.series && <ReviewRow label="Series" value={form.series} />}

      {form.error && <ReviewRow label="Error" value={form.error} valueColor="var(--cream-status-error)" />}
    </div>
  );
}

export function PublishFooter({ form }) {
  return (
    <button
      onClick={form.advance}
      disabled={!form.canAdvance || form.publishing}
      style={{
        width: '100%',
        height: 44,
        borderRadius: 10,
        background: 'var(--cream-cta-fill)',
        color: 'var(--cream-text-inverse)',
        fontFamily: 'var(--font-geist)',
        fontSize: 16,
        fontWeight: 500,
        opacity: !form.canAdvance || form.publishing ? 0.5 : 1,
        transition: 'opacity 0.15s',
      }}
    >
      {form.publishing ? 'Publishing…' : form.tab === 'Review' ? 'Publish' : 'Save and continue'}
    </button>
  );
}

function MetadataOptionRow({ icon, label, trailing, countBadge, onClick }) {
  return (
    <button
      onClick={onClick}
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '12px 14px',
        width: '100%',
        textAlign: 'left',
        background: 'transparent',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <span style={{ width: 20, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{icon}</span>
        <span style={{ fontFamily: 'var(--font-inter)', fontSize: 14, fontWeight: 500, color: 'var(--cream-text)' }}>{label}</span>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        {trailing && (
          <span style={{ fontFamily: 'var(--font-inter)', fontSize: 12, color: 'var(--cream-text-secondary)', maxWidth: 160, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
            {trailing}
          </span>
        )}
        {countBadge > 0 && (
          <span
            style={{
              width: 18,
              height: 18,
              borderRadius: '50%',
              background: 'var(--cream-text)',
              color: '#fff',
              fontSize: 10,
              fontWeight: 500,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            {countBadge}
          </span>
        )}
        <ChevronRightIcon width={7} height={12} color="#8C8880" />
      </div>
    </button>
  );
}

function Divider() {
  return <div style={{ height: 1, background: 'rgba(35,31,27,0.08)', marginLeft: 44 }} />;
}

function Toggle({ checked, onChange }) {
  return (
    <button
      onClick={() => onChange(!checked)}
      style={{
        width: 44,
        height: 26,
        borderRadius: 13,
        background: checked ? 'var(--cream-cta-fill)' : 'var(--cream-hairline)',
        position: 'relative',
        transition: 'background 0.15s',
      }}
    >
      <span
        style={{
          position: 'absolute',
          top: 2,
          left: checked ? 20 : 2,
          width: 22,
          height: 22,
          borderRadius: '50%',
          background: '#fff',
          transition: 'left 0.15s',
        }}
      />
    </button>
  );
}

function PillField({ placeholder, value, onChange, type = 'text' }) {
  return (
    <input
      type={type}
      placeholder={placeholder}
      value={value}
      onChange={(e) => onChange(e.target.value)}
      style={{
        height: 46,
        borderRadius: 14,
        background: 'var(--cream-bg-detail)',
        border: '1px solid rgba(35,31,27,0.15)',
        padding: '0 16px',
        fontFamily: 'var(--font-inter)',
        fontSize: 14,
        color: 'var(--cream-text)',
        outline: 'none',
      }}
    />
  );
}
