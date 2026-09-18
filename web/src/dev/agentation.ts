/**
 * Mounts the Agentation feedback toolbar: click an element, write a note, and
 * copy the notes as structured markdown for a coding agent.
 *
 * Dev only. Base.astro adds the script tag for this file under `astro dev`
 * alone, and nothing imports it, so a production build never bundles it or
 * React. That is also why this mounts React by hand instead of going through
 * an Astro island: Astro bundles every `client:only` component it sees, even
 * one behind `import.meta.env.DEV`.
 */
import { createElement } from 'react';
import { createRoot } from 'react-dom/client';
import { Agentation } from 'agentation';

const host = document.createElement('div');
host.id = 'agentation-root';
document.body.append(host);
createRoot(host).render(createElement(Agentation));
