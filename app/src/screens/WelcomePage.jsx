import React from 'react';
import { useNavigate } from 'react-router-dom';
import { PartyPopper } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { AuthPageTitle, AuthPrimaryButton, AuthScaffold } from '../components/auth/AuthUI';

/** Shown right after account creation — ported from lib/screens/welcome_page.dart. */
export function WelcomePage() {
  const navigate = useNavigate();
  const { user } = useAuth();

  return (
    <AuthScaffold compact>
      <div style={{ textAlign: 'center' }}>
        <PartyPopper size={52} color="#fff" strokeWidth={1.5} style={{ margin: '0 auto 20px' }} />
        <AuthPageTitle
          align="center"
          title="Welcome!"
          subtitle={user?.username ? `Your Studio 3 account @${user.username} is ready.` : 'Your Studio 3 account is ready.'}
        />
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
        <AuthPrimaryButton onClick={() => navigate(user?.onboardingComplete ? '/home' : '/onboarding', { replace: true })}>
          Get Started
        </AuthPrimaryButton>
      </div>
    </AuthScaffold>
  );
}
