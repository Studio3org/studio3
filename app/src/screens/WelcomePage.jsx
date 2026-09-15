import React from 'react';
import { useNavigate } from 'react-router-dom';
import { PartyPopper } from 'lucide-react';
import { AuthPageTitle, AuthPrimaryButton, AuthScaffold } from '../components/auth/AuthUI';

/** Shown right after account creation — ported from lib/screens/welcome_page.dart. */
export function WelcomePage() {
  const navigate = useNavigate();

  return (
    <AuthScaffold compact>
      <div style={{ textAlign: 'center' }}>
        <PartyPopper size={52} color="#fff" strokeWidth={1.5} style={{ margin: '0 auto 20px' }} />
        <AuthPageTitle align="center" title="Welcome!" subtitle="Your Studio 3 account is ready." />
        <p
          style={{
            fontFamily: 'var(--font-inter)',
            fontSize: 14,
            color: 'var(--auth-text-dim)',
            lineHeight: 1.5,
            marginBottom: 32,
          }}
        >
          Start discovering art, collecting stories, and sharing your creative journey.
        </p>
        <AuthPrimaryButton onClick={() => navigate('/onboarding')}>Get Started</AuthPrimaryButton>
      </div>
    </AuthScaffold>
  );
}
