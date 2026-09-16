/**
 * Which install hint, if any, the site should show.
 *
 * Chromium browsers fire `beforeinstallprompt` and can show a real install
 * button. iOS has no such event: the only way in is Share, then Add to Home
 * Screen, which almost nobody discovers unprompted, so iOS gets written
 * instructions instead.
 */
export type InstallHintKind = 'prompt' | 'ios' | null;

export interface InstallEnvironment {
  userAgent: string;
  /** `navigator.maxTouchPoints`; separates an iPad from a Mac. */
  maxTouchPoints: number;
  /** Already launched from the home screen. */
  standalone: boolean;
  /** A deferred `beforeinstallprompt` event is available. */
  hasPrompt: boolean;
  /** The reader closed the hint before. */
  dismissed: boolean;
}

// In-app browsers (Facebook, Instagram, Zalo, LINE, Messenger...) render pages
// in a web view with no Share > Add to Home Screen, so instructions would lead
// nowhere.
const IN_APP_BROWSER = /FBAN|FBAV|FB_IAB|Instagram|Zalo|Line\/|Messenger|MicroMessenger/i;

export function isIos(userAgent: string, maxTouchPoints: number): boolean {
  if (/iPhone|iPad|iPod/i.test(userAgent)) {
    return true;
  }
  // iPadOS 13+ reports a desktop Mac user agent. A Mac has no touch screen,
  // so touch support is what gives the iPad away.
  return /Macintosh/i.test(userAgent) && maxTouchPoints > 1;
}

export function installHintKind(env: InstallEnvironment): InstallHintKind {
  if (env.standalone || env.dismissed) {
    return null;
  }
  if (env.hasPrompt) {
    return 'prompt';
  }
  if (
    isIos(env.userAgent, env.maxTouchPoints) &&
    !IN_APP_BROWSER.test(env.userAgent)
  ) {
    return 'ios';
  }
  return null;
}
