import { useState } from 'react';
import { createEvent } from '../../services/eventsApi';
import { uploadMedia } from '../../services/postingApi';
import { renderMediaItem } from './mediaRenderer';
import { useMediaEditor } from './useMediaEditor';
import { eventDateSummary } from './eventDateUtils';
import { ticketIsComplete } from './eventTicketUtils';

export const EVENT_STEPS = ['Details', 'Tickets', 'Lineup', 'Review'];

/** All state + the publish flow for the Event creation wizard — mirrors
 * usePostForm's shape (same `media`/`step`/`goTo*` contract, so the
 * cover-photo gallery/edit stages reuse MediaGalleryStep/MediaEditStep
 * unchanged) but drives its own Details/Tickets/Lineup/Review wizard
 * instead of Piece/Scene tabs, matching lib/screens/event_create_page.dart. */
export function useEventForm(onPublished) {
  const media = useMediaEditor('event');
  const [step, setStep] = useState('gallery'); // 'gallery' | 'edit' | 'tabs'
  const [wizardStep, setWizardStep] = useState(0);

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [location, setLocation] = useState('');
  const [eventDate, setEventDate] = useState(null);
  const [categoryId, setCategoryId] = useState('');
  const [isPublic, setIsPublic] = useState(false);

  const [paid, setPaid] = useState(null); // null | true | false
  const [tickets, setTickets] = useState([]);

  const [lineup, setLineup] = useState('');

  const [publishing, setPublishing] = useState(false);
  const [error, setError] = useState('');

  const hasCompleteTicket = tickets.some(ticketIsComplete);
  const canAdvance =
    media.items.length > 0 &&
    (wizardStep !== 0 || title.trim().length > 0) &&
    (wizardStep !== 1 || paid === false || (paid === true && hasCompleteTicket));

  const goToGallery = () => setStep('gallery');
  const goToEdit = () => media.items.length > 0 && setStep('edit');
  const goToTabs = () => setStep('tabs');
  const goToEditOrTabs = () => setStep('edit');

  // Only ever-visited steps are tappable — matches event_create_page.dart's
  // `if (i <= _step) setState(() => _step = i)` (jumping back re-locks the
  // steps ahead of it, unlike the Piece/Scene flow's "furthest unlocked").
  const goWizardStep = (i) => {
    if (i <= wizardStep) setWizardStep(i);
  };

  const choosePaid = (value) => {
    setPaid(value);
    if (value && tickets.length === 0) {
      setTickets([{ name: 'General Admission', isFree: false, buyerPays: null, limitPurchaseWindow: false, startsSelling: null, stopsSelling: null, description: '', limitQuantity: false, quantity: null, limitPerOrder: false, perOrder: null }]);
    }
  };

  const addTicket = (ticket) => setTickets((current) => [...current, ticket]);
  const updateTicket = (index, ticket) =>
    setTickets((current) => current.map((t, i) => (i === index ? ticket : t)));

  const publish = async () => {
    if (media.items.length === 0 || publishing) return;
    setPublishing(true);
    setError('');
    try {
      const cover = media.items[0];
      const coverImageUrl = await uploadMedia(await renderMediaItem(cover), 'event');
      await createEvent({
        title: title.trim(),
        description: description.trim() || undefined,
        coverImageUrl,
        coverMediaAspectRatio: '3:4',
        location: location || undefined,
        ...(eventDate
          ? {
              startDate: eventDate.startDate,
              endDate: eventDate.multiDay ? eventDate.endDate : undefined,
              startTime: eventDate.startTime || undefined,
              endTime: eventDate.endTime || undefined,
              multiDay: eventDate.multiDay,
            }
          : {}),
        categoryId: categoryId || undefined,
        isPublic,
        isPaid: paid === true,
        tickets: paid === true ? tickets.filter(ticketIsComplete) : undefined,
        featuredArtists: lineup.trim() || undefined,
        status: 'live',
      });
      onPublished?.();
    } catch (e) {
      setError(e?.message || 'Something went wrong publishing this — please try again.');
    } finally {
      setPublishing(false);
    }
  };

  const advance = () => {
    if (!canAdvance) return;
    if (wizardStep < EVENT_STEPS.length - 1) {
      setWizardStep(wizardStep + 1);
    } else {
      publish();
    }
  };

  return {
    media,
    step,
    goToGallery,
    goToEdit,
    goToTabs,
    goToEditOrTabs,
    STEPS: EVENT_STEPS,
    wizardStep,
    goWizardStep,
    advance,
    canAdvance,
    publishing,
    error,
    title,
    setTitle,
    description,
    setDescription,
    location,
    setLocation,
    eventDate,
    setEventDate,
    eventDateSummary: eventDate ? eventDateSummary(eventDate) : '',
    categoryId,
    setCategoryId,
    isPublic,
    setIsPublic,
    paid,
    choosePaid,
    tickets,
    addTicket,
    updateTicket,
    lineup,
    setLineup,
  };
}
