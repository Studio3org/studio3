import React from 'react';

/**
 * Public, unauthenticated page describing how to delete a Studio3 account and what
 * happens to the data behind it — the URL Google Play's Data Safety form asks for.
 *
 * Deliberately not gated by RequireAuth (see App.jsx): someone who has lost access to
 * their account, or who never installed the app at all, still has to be able to reach
 * this page and find a way to ask for deletion.
 *
 * The wording below is not generic boilerplate — it describes exactly what
 * DELETE /api/users/me does today (see auth_controller.delete_account in the backend):
 * personal fields are scrubbed and the account is deactivated immediately, but a piece,
 * scene, or message the account created is not torn out of other people's order history
 * or conversations — it stays, re-attributed to an anonymized "Deleted user". If that
 * behavior ever changes, update this copy to match it rather than the other way round.
 */
export function DeleteAccountPage() {
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
          You can delete your Studio3 account and the personal data tied to it at any
          time — whether or not you still have the app installed.
        </p>

        <Section title="If you can sign in: do it in the app">
          <ol style={ol}>
            <li>Open Studio3 and go to your <strong>Profile</strong>.</li>
            <li>Tap the settings icon, then scroll to <strong>Delete account</strong>.</li>
            <li>Tell us why you're leaving, enter your password, and confirm.</li>
          </ol>
          <p style={p}>
            This takes effect immediately — your session ends and your login stops
            working right away. If you have an active listing for sale or an
            order/sale still in progress, you'll be asked to resolve those first, since
            an auction or a shipment can't be left with nobody behind it.
          </p>
        </Section>

        <Section title="If you can't sign in">
          <p style={p}>
            Email <a href="mailto:support@studio-3.co" style={link}>support@studio-3.co</a>{' '}
            from the address on the account (or tell us the username), and ask us to
            delete it. We'll verify it's really you and process it within 30 days.
          </p>
        </Section>

        <Section title="Delete some of your data without deleting your account">
          <p style={p}>
            You don't have to delete your whole account to remove something specific.
            Open the piece or scene from your <strong>Profile</strong>, tap the ⋯ menu on
            it, and choose <strong>Delete</strong> — this removes that item immediately
            and doesn't touch anything else on your account.
          </p>
          <p style={p}>
            For anything the app doesn't give you a direct delete option for — a message,
            a comment, or data you can't reach yourself — email{' '}
            <a href="mailto:support@studio-3.co" style={link}>support@studio-3.co</a> and
            tell us what to remove; we'll process it within 30 days.
          </p>
        </Section>

        <Section title="What actually gets deleted">
          <p style={p}>
            Your name, email address, phone number, bio, location, profile and cover
            photos, and any linked social accounts are permanently removed, and your
            password is cleared — nobody can sign in as you again.
          </p>
          <p style={p}>
            Your pieces, scenes, and hosted events are deleted along with the rest of
            your data — they don't linger under an anonymized name. The one exception is
            a message you sent, or a piece already part of a completed order: those can
            still be part of someone else's conversation or order history, so rather
            than deleting them outright, they stay — re-attributed to an anonymized
            "Deleted user" with none of your personal information attached.
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
