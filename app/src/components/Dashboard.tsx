import { Spinner, Button, Badge } from '@frhamon/design-system';
import { useSessions, useSessionStats } from '../hooks/useSessions';
import { StatCard } from './StatCard';
import { SessionList } from './SessionList';
import { PaymentChart, MonthlyChart, PractitionerChart } from './Charts';
import { InfoSection } from './InfoSection';
import './Dashboard.css';

export function Dashboard() {
  const { sessions, loading, refreshing, error, refresh, lastUpdated } = useSessions();
  const {
    paymentStats,
    practitionerStats,
    monthlyStats,
    upcomingSessions,
    recentSessions,
    maxSessionsMonth,
    averagePerMonth,
  } = useSessionStats(sessions);

  if (loading) {
    return (
      <div className="dashboard-loading">
        <Spinner size="lg" label="Chargement des séances..." />
      </div>
    );
  }

  const formattedLastUpdated = lastUpdated
    ? lastUpdated.toLocaleDateString('fr-FR', {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      })
    : 'Jamais';

  return (
    <div className="dashboard">
      <header className="dashboard__header">
        <h1 className="dashboard__title">Kinésithérapie 2025-2026</h1>
        <p className="dashboard__subtitle">Vue consolidée avec suivi des paiements</p>
        <div className="dashboard__actions">
          <Button
            onClick={refresh}
            disabled={refreshing}
            variant="secondary"
            size="sm"
          >
            {refreshing ? 'Mise à jour...' : 'Actualiser'}
          </Button>
        </div>
        {error && (
          <Badge variant="error" className="dashboard__error">
            {error}
          </Badge>
        )}
        {refreshing && (
          <Badge variant="info" className="dashboard__refreshing">
            Mise à jour en arrière-plan...
          </Badge>
        )}
      </header>

      {/* Statistiques de paiement */}
      <section className="dashboard__stats-grid">
        <StatCard
          label="Payées"
          value={paymentStats.paid2025 + paymentStats.paid2026}
          detail={`${Math.round(((paymentStats.paid2025 + paymentStats.paid2026) / paymentStats.total) * 100)}% du total`}
          variant="success"
          icon="✅"
        />
        <StatCard
          label="À effectuer"
          value={paymentStats.pending}
          detail={upcomingSessions.length > 0
            ? upcomingSessions[0].date.toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' })
            : 'Aucune'
          }
          variant="info"
          icon="📅"
        />
      </section>

      {/* Statistiques globales */}
      <section className="dashboard__stats-grid dashboard__stats-grid--4col">
        <StatCard
          label="Total"
          value={paymentStats.total}
          detail="séances"
        />
        <StatCard
          label="Période"
          value={`${monthlyStats.length} mois`}
          detail="continus"
        />
        {practitionerStats.map(stat => (
          <StatCard
            key={stat.name}
            label={stat.name}
            value={stat.count}
            detail={`${stat.percentage}%`}
          />
        ))}
      </section>

      {/* Graphique état des paiements */}
      <PaymentChart stats={paymentStats} />

      {/* Liste des séances 2026 */}
      <SessionList
        title="📋 Détail des séances 2026"
        sessions={[...recentSessions, ...upcomingSessions].slice(0, 10)}
      />

      {/* Graphique évolution mensuelle */}
      <MonthlyChart stats={monthlyStats} />

      {/* Répartition par praticien */}
      <PractitionerChart stats={practitionerStats} />

      {/* Statistiques détaillées */}
      <InfoSection
        title="📊 Statistiques"
        items={[
          { icon: '🏆', label: 'Mois max', value: `${maxSessionsMonth.month} (${maxSessionsMonth.total} séances)` },
          { icon: '📅', label: 'Moyenne', value: `${averagePerMonth} séances/mois` },
          { icon: '🔄', label: 'Transition', value: 'Août 2025 (Gigoux → Tindano)' },
          { icon: '💰', label: 'Total payé', value: `${paymentStats.paid2025 + paymentStats.paid2026} séances` },
          { icon: '📅', label: 'À venir', value: `${paymentStats.pending} séances` },
        ]}
      />

      {/* Infos pratiques */}
      <InfoSection
        title="ℹ️ Infos pratiques"
        items={[
          { icon: '📍', label: 'Lieu', value: '24 Rue du Javelot, 75013' },
          { icon: '⏰', label: 'Horaire', value: 'Généralement 12h15-13h15' },
          { icon: '🏢', label: 'Accès', value: 'RDC, dalle Olympiades' },
          { icon: '🔄', label: 'Mis à jour', value: formattedLastUpdated },
        ]}
      />
    </div>
  );
}
