import { describe, expect, it } from 'vitest';
import { installHintKind, isIos, type InstallEnvironment } from '../src/lib/install';

const UA = {
  iphoneSafari:
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1',
  iphoneChrome:
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/130.0 Mobile/15E148 Safari/604.1',
  // iPadOS 13+ asks for the desktop site and reports itself as a Mac.
  ipadDesktopMode:
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15',
  macSafari:
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15',
  facebookInApp:
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 [FBAN/FBIOS;FBAV/480.0]',
  zaloInApp:
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Zalo iOS',
  androidChrome:
    'Mozilla/5.0 (Linux; Android 15; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36',
};

function env(overrides: Partial<InstallEnvironment>): InstallEnvironment {
  return {
    userAgent: UA.androidChrome,
    maxTouchPoints: 0,
    standalone: false,
    hasPrompt: false,
    dismissed: false,
    ...overrides,
  };
}

describe('isIos', () => {
  it('recognises iPhone browsers', () => {
    expect(isIos(UA.iphoneSafari, 5)).toBe(true);
    expect(isIos(UA.iphoneChrome, 5)).toBe(true);
  });

  it('tells an iPad in desktop mode from a real Mac by touch support', () => {
    expect(isIos(UA.ipadDesktopMode, 5)).toBe(true);
    expect(isIos(UA.macSafari, 0)).toBe(false);
  });

  it('does not treat Android as iOS', () => {
    expect(isIos(UA.androidChrome, 5)).toBe(false);
  });
});

describe('installHintKind', () => {
  it('shows written instructions on iOS, which has no install prompt', () => {
    expect(installHintKind(env({ userAgent: UA.iphoneSafari, maxTouchPoints: 5 }))).toBe('ios');
  });

  it('prefers the real install button whenever the browser offers one', () => {
    expect(installHintKind(env({ hasPrompt: true }))).toBe('prompt');
  });

  it('shows nothing on a browser that can neither prompt nor add to home', () => {
    expect(installHintKind(env({ userAgent: UA.androidChrome }))).toBeNull();
    expect(installHintKind(env({ userAgent: UA.macSafari }))).toBeNull();
  });

  it('shows nothing once launched from the home screen', () => {
    expect(
      installHintKind(env({ userAgent: UA.iphoneSafari, maxTouchPoints: 5, standalone: true })),
    ).toBeNull();
    expect(installHintKind(env({ hasPrompt: true, standalone: true }))).toBeNull();
  });

  it('respects a dismissal', () => {
    expect(
      installHintKind(env({ userAgent: UA.iphoneSafari, maxTouchPoints: 5, dismissed: true })),
    ).toBeNull();
  });

  it('stays quiet inside in-app browsers, which have no Add to Home Screen', () => {
    expect(installHintKind(env({ userAgent: UA.facebookInApp, maxTouchPoints: 5 }))).toBeNull();
    expect(installHintKind(env({ userAgent: UA.zaloInApp, maxTouchPoints: 5 }))).toBeNull();
  });
});
