import React, { useEffect } from 'react';
import { Link } from 'react-router-dom';
import './AccountDeletionPage.css';

const SUPPORT_EMAIL = 'support@studio-3.co';
const mailto = (subject) => `mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent(subject)}`;

/**
 * Public, unauthenticated page describing how to delete a Studio3 account and what
 * happens to the data behind it — the URL Google Play's Data safety form asks for
 * (https://studio-3.co/delete-account).
 *
 * Deliberately not gated on login (see App.jsx): someone who has lost access to their
 * account, or who never installed the app at all, still has to be able to reach this page
 * and find a way to ask for deletion. The signed-in deletion form itself lives at
 * /settings/delete-account (DeleteAccountPage).
 *
 * The wording describes exactly what DELETE /api/user/me does today (see
 * auth_controller.delete_account in the backend) and matches the backend's own copy at
 * api.studio-3.co/delete-account (src/templates/legal/delete_account.html). If that
 * behavior ever changes, update this copy to match it rather than the other way round.
 */
export function AccountDeletionPage() {
  useFullBleedPage('Delete your account — Studio3');

  return (
    <div className="del-page">
      <header className="del-header">
        <div className="del-container">
          <Link to="/home" aria-label="Studio3 home">
            <img className="del-logo" src="/logo/logo_text_black.png" alt="Studio3" />
          </Link>
          <Link to="/home" className="del-header-link">
            Back to Studio3
          </Link>
        </div>
      </header>

      <main>
        <div className="del-container">
          <section className="del-hero">
            <p className="del-eyebrow">Account &amp; data</p>
            <h1 className="del-title">Delete your account</h1>
            <p className="del-lede">
              You can delete your Studio3 account and the personal data tied to it at any
              time — in the app, on the web, or by emailing us, whether or not you still have
              the app installed.
            </p>
          </section>

          <div className="del-ways">
            <Card step="1" title="In the Studio3 app">
              <ol className="del-list">
                <li>Open Studio3 and go to your <strong>Profile</strong>.</li>
                <li>Tap the <strong>settings</strong> button at the top of your profile.</li>
                <li>Scroll to the bottom and tap <strong>Delete account</strong>.</li>
                <li>Enter your password and confirm.</li>
              </ol>
            </Card>

            <Card
              step="2"
              title="On the web"
              action={
                <Link to="/settings/delete-account" className="del-button">
                  Delete my account
                </Link>
              }
            >
              <p>
                Sign in at studio-3.co and delete your account from <strong>Settings</strong>.
                You'll be asked to confirm with your password.
              </p>
            </Card>

            <Card
              step="3"
              title="If you can't sign in"
              action={
                <a href={mailto('Delete my Studio3 account')} className="del-button del-button--ghost">
                  Email {SUPPORT_EMAIL}
                </a>
              }
            >
              <p>
                Email us from the address on the account (or tell us your username) and ask us
                to delete it. We'll verify it's really you and process it within 30 days.
              </p>
            </Card>
          </div>

          <div className="del-details">
            <Section title="When it takes effect">
              <p>
                Deletion is immediate: you're signed out everywhere and your login stops
                working right away.
              </p>
              <p>
                If you have a piece listed for sale or an order or sale still in progress,
                you'll be asked to resolve it first — an auction or a shipment can't be left
                with nobody behind it.
              </p>
            </Section>

            <Section title="What gets deleted">
              <ul className="del-list">
                <li>
                  Your name, username, email address, phone number, bio, location, links, and
                  profile and cover photos — and your password, so nobody can sign in as you
                  again.
                </li>
                <li>Your pieces, scenes, and hosted events.</li>
                <li>Your comments, likes, saves and collections, follows, and blocks.</li>
                <li>
                  Your notifications and the devices registered to receive them, and all your
                  sessions.
                </li>
              </ul>
            </Section>

            <Section title="What's kept">
              <p>
                A message you sent, or a piece that's already part of a completed order, is
                also part of someone else's conversation or purchase history. Those aren't
                removed — they stay attributed to an anonymized "Deleted user", with none of
                your personal information attached.
              </p>
            </Section>

            <Section title="Delete some of your data without deleting your account">
              <p>
                Open the piece or scene on your <strong>Profile</strong>, tap its{' '}
                <strong>⋯</strong> menu, and choose <strong>Delete</strong> — that item is
                removed immediately and nothing else on your account changes. You can also
                edit or clear your profile details (bio, location, photos, links) at any time
                from <strong>Edit profile</strong>.
              </p>
              <p>
                For anything you can't remove yourself — a comment, a message, or other data —
                email{' '}
                <a href={mailto('Delete my Studio3 data')} className="del-link">
                  {SUPPORT_EMAIL}
                </a>{' '}
                and tell us what to delete; we'll process it within 30 days.
              </p>
            </Section>
          </div>
        </div>
      </main>

      <footer className="del-footer">
        <div className="del-container">
          <span>
            Questions? Reach us any time at{' '}
            <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>.
          </span>
          <span>© {new Date().getFullYear()} Studio3</span>
        </div>
      </footer>
    </div>
  );
}

/// One of the three ways to delete — numbered, with an optional action pinned to the bottom
/// so the buttons line up when the cards sit side by side on desktop.
function Card({ step, title, action, children }) {
  return (
    <section className="del-card">
      <span className="del-card-step" aria-hidden>
        {step}
      </span>
      <h2>{title}</h2>
      {children}
      {action && <div className="del-actions">{action}</div>}
    </section>
  );
}

function Section({ title, children }) {
  return (
    <section className="del-section">
      <h2>{title}</h2>
      {children}
    </section>
  );
}

/// The rest of the web app is framed to a phone-width column (#root max-width in
/// index.css); this public page spans the whole window, so lift that frame while it's
/// mounted and restore it on the way out.
function useFullBleedPage(title) {
  useEffect(() => {
    const root = document.documentElement;
    const previousTitle = document.title;
    root.classList.add('page-full-bleed');
    document.title = title;
    return () => {
      root.classList.remove('page-full-bleed');
      document.title = previousTitle;
    };
  }, [title]);
}
