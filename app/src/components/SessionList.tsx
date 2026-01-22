import { Card } from '@frhamon/design-system';
import type { Session } from '../types';
import './SessionList.css';

interface SessionListProps {
  title: string;
  sessions: Session[];
  showYear?: boolean;
}

export function SessionList({ title, sessions, showYear = false }: SessionListProps) {
  const formatDate = (date: Date) => {
    return date.toLocaleDateString('fr-FR', {
      day: '2-digit',
      month: '2-digit',
      year: showYear ? 'numeric' : undefined,
    });
  };

  const getDayName = (date: Date) => {
    return date.toLocaleDateString('fr-FR', { weekday: 'long' });
  };

  return (
    <Card className="session-list">
      <h2 className="session-list__title">{title}</h2>
      <div className="session-list__items">
        {sessions.map(session => (
          <div
            key={session.id}
            className={`session-item ${session.paid ? 'session-item--paid' : 'session-item--future'}`}
          >
            <span className="session-item__date">{formatDate(session.date)}</span>
            <span className="session-item__status">
              {session.paid ? (
                <>
                  <span className="session-item__check">✓</span> Payé
                  {session.paidDate && ` le ${formatDate(session.paidDate)}`}
                </>
              ) : (
                <>
                  <span className="session-item__calendar">📅</span> À venir ({getDayName(session.date)})
                </>
              )}
            </span>
          </div>
        ))}
        {sessions.length === 0 && (
          <div className="session-list__empty">Aucune séance</div>
        )}
      </div>
    </Card>
  );
}
