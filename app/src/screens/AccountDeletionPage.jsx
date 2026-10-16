import React from 'react';
import { Link } from 'react-router-dom';

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
  return (
    <div
      style={{
        minHeight: '100vh',
        background: 'var(--off-white, #f8f8f8)',
        display: 'flex',
        justifyContent: 'center',
        padding: '48px 20px 80px',
      }}
    >
      <div style={{ width: '100%', maxWidth: 640 }}>
        <div style={{ marginBottom: 32 }}>
          <div
            style={{
              fontFamily: 'Geist, sans-serif',
              fontWeight: 800,
              fontSize: 20,
              letterSpacing: '-0.02em',
              color: 'var(--slate-900, #0f172a)',
            }}
          >
            Studio3
          </div>
        </div>

        <h1
          style={{
            fontFamily: 'Geist, sans-serif',
            fontWeight: 700,
            fontSize: 32,
            lineHeight: 1.15,
            color: 'var(--slate-900, #0f172a)',
            margin: '0 0 12px',
          }}
        >
          Delete your account
        </h1>
        <p
          style={{
            fontFamily: 'Inter, sans-serif',
            fontSize: 16,
            lineHeight: 1.6,
            color: 'var(--slate-600, #475569)',
            margin: '0 0 40px',
          }}
        >
          You can delete your Studio3 account and the personal data tied to it at any time —
          in the app, on the web, or by emailing us, whether or not you still have the app
          installed.
        </p>

        <Section title="In the Studio3 app">
          <ol style={ol}>
            <li>Open Studio3 and go to your <strong>Profile</strong>.</li>
            <li>Tap the <strong>settings</strong> button at the top of your profile.</li>
            <li>Scroll to the bottom and tap <strong>Delete account</strong>.</li>
            <li>Enter your password and confirm.</li>
          </ol>
        </Section>

        <Section title="On the web">
          <p style={p}>Sign in at studio-3.co and delete your account from Settings.</p>
          <Link to="/settings/delete-account" style={button}>
            Delete my account
          </Link>
        </Section>

        <Section title="If you can't sign in">
          <p style={p}>
            Email{' '}
            <a href="mailto:support@studio-3.co?subject=Delete%20my%20Studio3%20account" style={link}>
              support@studio-3.co
            </a>{' '}
            from the address on the account (or tell us your username) and ask us to delete
            it. We'll verify it's really you and process it within 30 days.
          </p>
        </Section>

        <Section title="When it takes effect">
          <p style={p}>
            Deletion is immediate: you're signed out everywhere and your login stops working
            right away. If you have a piece listed for sale or an order or sale still in
            progress, you'll be asked to resolve it first — an auction or a shipment can't be
            left with nobody behind it.
          </p>
        </Section>

        <Section title="What gets deleted">
          <ul style={ol}>
            <li>
              Your name, username, email address, phone number, bio, location, links, and
              profile and cover photos — and your password, so nobody can sign in as you again.
            </li>
            <li>Your pieces, scenes, and hosted events.</li>
            <li>Your comments, likes, saves and collections, follows, and blocks.</li>
            <li>
              Your notifications and the devices registered to receive them, and all your
              sessions.
            </li>
          </ul>
          <p style={p}>
            <strong>What's kept:</strong> a message you sent, or a piece that's already part of
            a completed order, is also part of someone else's conversation or purchase history.
            Those aren't removed — they stay attributed to an anonymized "Deleted user", with
            none of your personal information attached.
          </p>
        </Section>

        <Section title="Delete some of your data without deleting your account">
          <p style={p}>
            Open the piece or scene on your <strong>Profile</strong>, tap its{' '}
            <strong>⋯</strong> menu, and choose <strong>Delete</strong> — that item is removed
            immediately and nothing else on your account changes. You can also edit or clear
            your profile details (bio, location, photos, links) at any time from{' '}
            <strong>Edit profile</strong>.
          </p>
          <p style={p}>
            For anything you can't remove yourself — a comment, a message, or other data —
            email{' '}
            <a href="mailto:support@studio-3.co?subject=Delete%20my%20Studio3%20data" style={link}>
              support@studio-3.co
            </a>{' '}
            and tell us what to delete; we'll process it within 30 days.
          </p>
        </Section>

        <Section title="Questions">
          <p style={p}>
            Reach us any time at{' '}
            <a href="mailto:support@studio-3.co" style={link}>support@studio-3.co</a>.
          </p>
        </Section>
      </div>
    </div>
  );
}

function Section({ title, children }) {
  return (
    <section style={{ marginBottom: 32 }}>
      <h2
        style={{
          fontFamily: 'Geist, sans-serif',
          fontWeight: 600,
          fontSize: 18,
          color: 'var(--slate-900, #0f172a)',
          margin: '0 0 10px',
        }}
      >
        {title}
      </h2>
      {children}
    </section>
  );
}

const p = {
  fontFamily: 'Inter, sans-serif',
  fontSize: 15,
  lineHeight: 1.65,
  color: 'var(--slate-700, #334155)',
  margin: '0 0 10px',
};

const ol = {
  ...p,
  paddingLeft: 20,
  margin: '0 0 12px',
};

const link = {
  color: 'var(--slate-900, #0f172a)',
  fontWeight: 600,
  textDecoration: 'underline',
};

const button = {
  display: 'inline-block',
  marginTop: 4,
  padding: '12px 20px',
  borderRadius: 9999,
  background: 'var(--slate-900, #0f172a)',
  color: 'var(--white, #fff)',
  fontFamily: 'Inter, sans-serif',
  fontSize: 15,
  fontWeight: 600,
  textDecoration: 'none',
};
