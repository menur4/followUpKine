export interface Session {
  id: string;
  date: Date;
  practitioner: string;
  paid: boolean;
  paidDate?: Date;
  location?: string;
  time?: string;
}

export interface CalendarEvent {
  id: string;
  summary: string;
  start: {
    dateTime?: string;
    date?: string;
  };
  end: {
    dateTime?: string;
    date?: string;
  };
  location?: string;
  description?: string;
  creator?: {
    email?: string;
    displayName?: string;
  };
}

export interface MonthlyStats {
  month: string;
  gigoux: number;
  tindano: number;
  total: number;
}

export interface PractitionerStats {
  name: string;
  count: number;
  percentage: number;
}

export interface PaymentStats {
  paid2025: number;
  paid2026: number;
  pending: number;
  total: number;
}
