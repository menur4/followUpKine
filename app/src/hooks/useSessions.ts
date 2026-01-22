import { useState, useEffect, useCallback } from 'react';
import type { Session, MonthlyStats, PractitionerStats, PaymentStats } from '../types';
import {
  fetchCalendarEvents,
  parseEventsToSessions,
  getMockSessions,
} from '../services/googleCalendar';

const API_KEY = import.meta.env.VITE_GOOGLE_API_KEY;
const CALENDAR_ID = import.meta.env.VITE_GOOGLE_CALENDAR_ID;

const CACHE_KEY = 'kine-sessions-cache';
const CACHE_TIMESTAMP_KEY = 'kine-sessions-cache-timestamp';
const CACHE_DURATION = 1000 * 60 * 60; // 1 heure

interface CachedSession {
  id: string;
  date: string; // ISO string
  practitioner: string;
  paid: boolean;
  paidDate?: string;
  location?: string;
  time?: string;
}

function loadFromCache(): Session[] | null {
  try {
    const cached = localStorage.getItem(CACHE_KEY);
    const timestamp = localStorage.getItem(CACHE_TIMESTAMP_KEY);

    if (cached && timestamp) {
      const cachedSessions: CachedSession[] = JSON.parse(cached);
      // Reconvertir les dates string en objets Date
      return cachedSessions.map(s => ({
        ...s,
        date: new Date(s.date),
        paidDate: s.paidDate ? new Date(s.paidDate) : undefined,
      }));
    }
  } catch (e) {
    console.warn('Failed to load from cache:', e);
  }
  return null;
}

function saveToCache(sessions: Session[]): void {
  try {
    // Convertir les dates en ISO string pour le stockage
    const toCache: CachedSession[] = sessions.map(s => ({
      ...s,
      date: s.date.toISOString(),
      paidDate: s.paidDate?.toISOString(),
    }));
    localStorage.setItem(CACHE_KEY, JSON.stringify(toCache));
    localStorage.setItem(CACHE_TIMESTAMP_KEY, Date.now().toString());
    console.log('💾 Sessions saved to cache:', sessions.length);
  } catch (e) {
    console.warn('Failed to save to cache:', e);
  }
}

function isCacheStale(): boolean {
  const timestamp = localStorage.getItem(CACHE_TIMESTAMP_KEY);
  if (!timestamp) return true;
  return Date.now() - parseInt(timestamp, 10) > CACHE_DURATION;
}

export function useSessions() {
  const [sessions, setSessions] = useState<Session[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);

  // Charger depuis l'API
  const fetchFromAPI = async (): Promise<Session[]> => {
    console.log('🚀 fetchFromAPI called');

    if (!API_KEY || !CALENDAR_ID) {
      console.warn('❌ API not configured, using mock data');
      return getMockSessions();
    }

    // Période : mars 2025 à décembre 2026
    const timeMin = new Date('2025-03-01T00:00:00Z').toISOString();
    const timeMax = new Date('2026-12-31T23:59:59Z').toISOString();

    const events = await fetchCalendarEvents(timeMin, timeMax);
    const parsedSessions = parseEventsToSessions(events);
    console.log('🎯 Parsed sessions:', parsedSessions.length);
    return parsedSessions;
  };

  // Charger les données (cache d'abord, puis API si nécessaire)
  const loadSessions = async (forceRefresh = false) => {
    console.log('📥 loadSessions called, forceRefresh:', forceRefresh);
    setError(null);

    // 1. Charger depuis le cache immédiatement
    const cached = loadFromCache();
    if (cached && cached.length > 0 && !forceRefresh) {
      console.log('📦 Loaded from cache:', cached.length, 'sessions');
      setSessions(cached);
      setLoading(false);

      const timestamp = localStorage.getItem(CACHE_TIMESTAMP_KEY);
      if (timestamp) {
        setLastUpdated(new Date(parseInt(timestamp, 10)));
      }

      // Si le cache n'est pas périmé, on s'arrête là
      if (!isCacheStale()) {
        console.log('✅ Cache is fresh, skipping API call');
        return;
      }
      console.log('⏰ Cache is stale, refreshing in background...');
    }

    // 2. Charger depuis l'API
    const isBackgroundRefresh = cached && cached.length > 0;
    if (isBackgroundRefresh) {
      setRefreshing(true);
    } else {
      setLoading(true);
    }

    try {
      const freshSessions = await fetchFromAPI();
      console.log('✅ Got fresh sessions:', freshSessions.length);
      setSessions(freshSessions);
      saveToCache(freshSessions);
      setLastUpdated(new Date());
    } catch (err) {
      console.error('❌ Failed to load sessions:', err);
      setError(err instanceof Error ? err.message : 'Erreur de chargement');

      // Si pas de cache, utiliser les données mock
      if (!cached || cached.length === 0) {
        console.log('⚠️ No cache, falling back to mock data');
        setSessions(getMockSessions());
      }
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  // Forcer un rafraîchissement depuis l'API
  const refresh = () => {
    return loadSessions(true);
  };

  useEffect(() => {
    console.log('🔄 useEffect triggered');
    loadSessions();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return { sessions, loading, refreshing, error, refresh, lastUpdated };
}

export function useSessionStats(sessions: Session[]) {
  const today = new Date();

  const paymentStats: PaymentStats = {
    paid2025: sessions.filter(
      s => s.paid && s.date.getFullYear() === 2025
    ).length,
    paid2026: sessions.filter(
      s => s.paid && s.date.getFullYear() === 2026
    ).length,
    pending: sessions.filter(s => !s.paid).length,
    total: sessions.length,
  };

  // Collecter dynamiquement tous les praticiens
  const practitionerCounts = new Map<string, number>();
  sessions.forEach(s => {
    const count = practitionerCounts.get(s.practitioner) || 0;
    practitionerCounts.set(s.practitioner, count + 1);
  });

  const practitionerStats: PractitionerStats[] = Array.from(practitionerCounts.entries())
    .map(([name, count]) => ({
      name,
      count,
      percentage: sessions.length ? Math.round((count / sessions.length) * 100) : 0,
    }))
    .sort((a, b) => b.count - a.count);

  const monthlyStats: MonthlyStats[] = [];
  const monthsMap = new Map<number, MonthlyStats & { sortKey: number }>();

  // Déterminer la dernière date à afficher :
  // - Le mois actuel OU le dernier mois avec une session (si dans le futur)
  const currentSortKey = today.getFullYear() * 100 + today.getMonth();
  const lastSessionSortKey = sessions.length > 0
    ? Math.max(...sessions.map(s => s.date.getFullYear() * 100 + s.date.getMonth()))
    : currentSortKey;
  const endSortKey = Math.max(currentSortKey, lastSessionSortKey);

  // Générer tous les mois de mars 2025 jusqu'à la fin déterminée
  const startYear = 2025;
  const startMonth = 2; // Mars (0-indexed)
  const endYear = Math.floor(endSortKey / 100);
  const endMonth = endSortKey % 100;

  for (let year = startYear; year <= endYear; year++) {
    const monthStart = year === startYear ? startMonth : 0;
    const monthEnd = year === endYear ? endMonth : 11;

    for (let month = monthStart; month <= monthEnd; month++) {
      const sortKey = year * 100 + month;
      const date = new Date(year, month, 1);
      const monthKey = date.toLocaleDateString('fr-FR', {
        month: 'short',
        year: '2-digit',
      });

      monthsMap.set(sortKey, {
        month: monthKey,
        gigoux: 0,
        tindano: 0,
        total: 0,
        sortKey,
      });
    }
  }

  // Remplir avec les données des sessions
  sessions.forEach(session => {
    const year = session.date.getFullYear();
    const month = session.date.getMonth();
    const sortKey = year * 100 + month;

    // Ajouter le mois s'il n'existe pas (session future au-delà du mois actuel)
    if (!monthsMap.has(sortKey)) {
      const date = new Date(year, month, 1);
      const monthKey = date.toLocaleDateString('fr-FR', {
        month: 'short',
        year: '2-digit',
      });
      monthsMap.set(sortKey, {
        month: monthKey,
        gigoux: 0,
        tindano: 0,
        total: 0,
        sortKey,
      });
    }

    const stats = monthsMap.get(sortKey)!;
    stats.total++;
    if (session.practitioner === 'C. Gigoux') {
      stats.gigoux++;
    } else {
      stats.tindano++;
    }
  });

  // Trier par date (sortKey = YYYYMM)
  const sortedMonths = Array.from(monthsMap.values())
    .sort((a, b) => a.sortKey - b.sortKey);

  sortedMonths.forEach(({ month, gigoux, tindano, total }) => {
    monthlyStats.push({ month, gigoux, tindano, total });
  });

  const upcomingSessions = sessions
    .filter(s => s.date > today)
    .sort((a, b) => a.date.getTime() - b.date.getTime());

  const recentSessions = sessions
    .filter(s => s.date <= today && s.date.getFullYear() === 2026)
    .sort((a, b) => b.date.getTime() - a.date.getTime());

  const maxSessionsMonth = monthlyStats.reduce(
    (max, stat) => (stat.total > max.total ? stat : max),
    { month: '-', total: 0, gigoux: 0, tindano: 0 }
  );

  const averagePerMonth =
    monthlyStats.length > 0
      ? (sessions.length / monthlyStats.length).toFixed(1)
      : '0';

  return {
    paymentStats,
    practitionerStats,
    monthlyStats,
    upcomingSessions,
    recentSessions,
    maxSessionsMonth,
    averagePerMonth,
  };
}
