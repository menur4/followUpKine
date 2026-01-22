import type { CalendarEvent, Session } from '../types';

const API_KEY = import.meta.env.VITE_GOOGLE_API_KEY;
const CALENDAR_ID = import.meta.env.VITE_GOOGLE_CALENDAR_ID;

// Email de l'utilisateur pour filtrer les événements créés par lui
const USER_EMAIL = 'hamonfrancois@gmail.com';

const PRACTITIONERS = {
  GIGOUX: 'C. Gigoux',
  TINDANO: 'L. Tindano',
};

// Noms des praticiens autorisés (insensible à la casse)
const ALLOWED_PRACTITIONERS = ['tindano', 'léonard', 'gigoux', 'corentin'];

// Pattern pour identifier les séances de kiné : "Rendez-vous chez [nom]" ou "RDV chez [nom]"
const KINE_PATTERN = /^(?:rendez-vous|rdv) chez\s+(.+)$/i;

export async function fetchCalendarEvents(
  timeMin: string,
  timeMax: string
): Promise<CalendarEvent[]> {
  console.log('🔍 Checking API config...', {
    hasApiKey: !!API_KEY,
    hasCalendarId: !!CALENDAR_ID,
    calendarId: CALENDAR_ID
  });

  if (!API_KEY || !CALENDAR_ID) {
    console.warn('❌ Google Calendar API not configured. Using mock data.');
    return [];
  }

  const allEvents: CalendarEvent[] = [];
  let pageToken: string | undefined;
  let pageCount = 0;

  do {
    const url = new URL(
      `https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(CALENDAR_ID)}/events`
    );

    url.searchParams.set('key', API_KEY);
    url.searchParams.set('timeMin', timeMin);
    url.searchParams.set('timeMax', timeMax);
    url.searchParams.set('singleEvents', 'true');
    url.searchParams.set('orderBy', 'startTime');
    url.searchParams.set('maxResults', '250');

    if (pageToken) {
      url.searchParams.set('pageToken', pageToken);
    }

    pageCount++;
    console.log(`📡 Fetching page ${pageCount} from Google Calendar API...`);

    const response = await fetch(url.toString());

    if (!response.ok) {
      const errorText = await response.text();
      console.error('❌ API Error:', response.status, errorText);
      throw new Error(`Google Calendar API error: ${response.status} - ${errorText}`);
    }

    const data = await response.json();
    const pageEvents = data.items || [];
    allEvents.push(...pageEvents);

    console.log(`✅ Page ${pageCount}: received ${pageEvents.length} events (total: ${allEvents.length})`);

    pageToken = data.nextPageToken;
  } while (pageToken);

  console.log(`🎉 Finished fetching all ${allEvents.length} events in ${pageCount} page(s)`);
  return allEvents;
}

function extractPractitionerName(event: CalendarEvent): string | null {
  const match = event.summary?.match(KINE_PATTERN);
  if (match) {
    return match[1].trim(); // Retourne le nom après "Rendez-vous chez"
  }
  return null;
}

function detectPractitioner(event: CalendarEvent): string {
  const practitionerName = extractPractitionerName(event);

  if (practitionerName) {
    const nameLower = practitionerName.toLowerCase();

    if (nameLower.includes('tindano') || nameLower.includes('léonard')) {
      return PRACTITIONERS.TINDANO;
    }
    if (nameLower.includes('gigoux') || nameLower.includes('corentin')) {
      return PRACTITIONERS.GIGOUX;
    }
  }

  // Fallback (ne devrait pas arriver avec le filtrage actuel)
  return PRACTITIONERS.TINDANO;
}

function isCreatedByUser(event: CalendarEvent): boolean {
  return event.creator?.email === USER_EMAIL;
}

function isAllowedPractitioner(event: CalendarEvent): boolean {
  const practitionerName = extractPractitionerName(event);
  if (!practitionerName) return false;

  const nameLower = practitionerName.toLowerCase();
  return ALLOWED_PRACTITIONERS.some(p => nameLower.includes(p));
}

function isKineSession(event: CalendarEvent): boolean {
  // Vérifie si l'événement:
  // 1. Correspond au pattern "Rendez-vous chez..."
  // 2. A été créé par l'utilisateur
  // 3. Concerne un praticien autorisé (Tindano ou Gigoux)
  const matchesPattern = KINE_PATTERN.test(event.summary || '');
  const createdByUser = isCreatedByUser(event);
  const allowedPractitioner = isAllowedPractitioner(event);

  return matchesPattern && createdByUser && allowedPractitioner;
}

function isPaid(event: CalendarEvent, today: Date): boolean {
  const eventDate = new Date(event.start.dateTime || event.start.date || '');
  // Les séances passées sont considérées comme payées
  return eventDate <= today;
}

export function parseEventsToSessions(events: CalendarEvent[]): Session[] {
  const today = new Date();

  console.log('🔍 Filtering events...');
  console.log('📊 Total events received:', events.length);

  // Debug: afficher les premiers événements pour comprendre la structure
  if (events.length > 0) {
    console.log('🔬 Premiers événements (debug):', events.slice(0, 5).map(e => ({
      summary: e.summary,
      creator: e.creator,
      matchesPattern: KINE_PATTERN.test(e.summary || ''),
      createdByUser: e.creator?.email === USER_EMAIL,
    })));
  }

  const kineEvents = events.filter(event => {
    const matchesPattern = KINE_PATTERN.test(event.summary || '');
    const createdByUser = event.creator?.email === USER_EMAIL;
    const practitionerName = extractPractitionerName(event);
    const allowedPractitioner = practitionerName
      ? ALLOWED_PRACTITIONERS.some(p => practitionerName.toLowerCase().includes(p))
      : false;

    // Log pour les événements qui matchent le pattern mais échouent sur d'autres critères
    if (matchesPattern && (!createdByUser || !allowedPractitioner)) {
      console.log('⚠️ Event rejected:', {
        summary: event.summary,
        creatorEmail: event.creator?.email,
        expectedEmail: USER_EMAIL,
        createdByUser,
        practitionerName,
        allowedPractitioner,
      });
    }

    return matchesPattern && createdByUser && allowedPractitioner;
  });

  console.log('✅ Found', kineEvents.length, 'kiné sessions out of', events.length, 'total events');
  if (kineEvents.length > 0) {
    console.log('📋 Séances trouvées:', kineEvents.map(e => ({
      title: e.summary,
      practitioner: extractPractitionerName(e),
      date: e.start.dateTime || e.start.date
    })));
  }

  return kineEvents
    .map(event => {
      const startDateTime = event.start.dateTime || event.start.date || '';
      const date = new Date(startDateTime);

      return {
        id: event.id,
        date,
        practitioner: detectPractitioner(event),
        paid: isPaid(event, today),
        paidDate: isPaid(event, today) ? today : undefined,
        location: event.location,
        time: event.start.dateTime
          ? new Date(event.start.dateTime).toLocaleTimeString('fr-FR', {
              hour: '2-digit',
              minute: '2-digit'
            })
          : undefined,
      };
    })
    .sort((a, b) => a.date.getTime() - b.date.getTime());
}

// Données de démonstration quand l'API n'est pas configurée
export function getMockSessions(): Session[] {
  const sessions: Session[] = [];

  // Données basées sur votre page HTML existante
  const data = [
    // 2025
    { month: 1, year: 2025, count: 1, practitioner: PRACTITIONERS.GIGOUX },
    { month: 2, year: 2025, count: 8, practitioner: PRACTITIONERS.GIGOUX },
    { month: 3, year: 2025, count: 5, practitioner: PRACTITIONERS.GIGOUX },
    { month: 4, year: 2025, count: 5, practitioner: PRACTITIONERS.GIGOUX },
    { month: 5, year: 2025, count: 6, practitioner: PRACTITIONERS.GIGOUX },
    { month: 6, year: 2025, count: 4, practitioner: PRACTITIONERS.GIGOUX },
    { month: 7, year: 2025, count: 6, practitioner: PRACTITIONERS.TINDANO },
    { month: 8, year: 2025, count: 4, practitioner: PRACTITIONERS.TINDANO },
    { month: 9, year: 2025, count: 5, practitioner: PRACTITIONERS.TINDANO },
    { month: 10, year: 2025, count: 1, practitioner: PRACTITIONERS.TINDANO },
    // 2026
    { month: 0, year: 2026, count: 4, practitioner: PRACTITIONERS.TINDANO },
    { month: 1, year: 2026, count: 2, practitioner: PRACTITIONERS.TINDANO },
  ];

  let id = 1;
  const today = new Date();

  data.forEach(({ month, year, count, practitioner }) => {
    for (let i = 0; i < count; i++) {
      const day = Math.min(28, 1 + i * 4);
      const date = new Date(year, month, day, 12, 15);
      const isPaidSession = date <= today;

      sessions.push({
        id: `mock-${id++}`,
        date,
        practitioner,
        paid: isPaidSession,
        paidDate: isPaidSession ? new Date(year, month, day + 5) : undefined,
        location: '24 Rue du Javelot, 75013 Paris',
        time: '12:15',
      });
    }
  });

  return sessions;
}
