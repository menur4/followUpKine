import { Card } from '@frhamon/design-system';
import './InfoSection.css';

interface InfoItem {
  icon: string;
  label: string;
  value: string;
}

interface InfoSectionProps {
  title: string;
  items: InfoItem[];
}

export function InfoSection({ title, items }: InfoSectionProps) {
  return (
    <Card className="info-section">
      <h2 className="info-section__title">{title}</h2>
      <div className="info-section__items">
        {items.map((item, index) => (
          <p key={index} className="info-section__item">
            <strong>
              {item.icon} {item.label}
            </strong>
            {item.value}
          </p>
        ))}
      </div>
    </Card>
  );
}
