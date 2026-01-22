import { Card } from '@frhamon/design-system';
import './StatCard.css';

interface StatCardProps {
  label: string;
  value: string | number;
  detail?: string;
  variant?: 'default' | 'success' | 'warning' | 'info';
  icon?: string;
}

export function StatCard({ label, value, detail, variant = 'default', icon }: StatCardProps) {
  return (
    <Card className={`stat-card stat-card--${variant}`}>
      <div className="stat-card__label">
        {icon && <span className="stat-card__icon">{icon}</span>}
        {label}
      </div>
      <div className="stat-card__value">{value}</div>
      {detail && <div className="stat-card__detail">{detail}</div>}
    </Card>
  );
}
