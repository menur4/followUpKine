import {
  Chart as ChartJS,
  ArcElement,
  CategoryScale,
  LinearScale,
  BarElement,
  Title,
  Tooltip,
  Legend,
} from 'chart.js';
import { Doughnut, Bar } from 'react-chartjs-2';
import { Card } from '@frhamon/design-system';
import type { MonthlyStats, PractitionerStats, PaymentStats } from '../types';
import './Charts.css';

ChartJS.register(
  ArcElement,
  CategoryScale,
  LinearScale,
  BarElement,
  Title,
  Tooltip,
  Legend
);

const commonOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: {
      display: true,
      position: 'top' as const,
      labels: {
        font: {
          size: 11,
          family: "'AB Chanel Corpo', 'Inter', system-ui, sans-serif",
        },
        padding: 10,
        boxWidth: 12,
        boxHeight: 12,
      },
    },
    tooltip: {
      enabled: true,
      backgroundColor: 'rgba(0,0,0,0.8)',
      padding: 12,
      titleFont: { size: 13 },
      bodyFont: { size: 12 },
    },
  },
};

interface PaymentChartProps {
  stats: PaymentStats;
}

export function PaymentChart({ stats }: PaymentChartProps) {
  const data = {
    labels: ['Payées (2025)', 'Payées (2026)', 'À effectuer'],
    datasets: [
      {
        data: [stats.paid2025, stats.paid2026, stats.pending],
        backgroundColor: [
          'rgba(5, 150, 105, 0.85)',
          'rgba(34, 197, 94, 0.85)',
          'rgba(2, 132, 199, 0.85)',
        ],
        borderWidth: 0,
      },
    ],
  };

  const options = {
    ...commonOptions,
    cutout: '65%',
    plugins: {
      ...commonOptions.plugins,
      legend: {
        ...commonOptions.plugins.legend,
        position: 'bottom' as const,
      },
      tooltip: {
        ...commonOptions.plugins.tooltip,
        callbacks: {
          label: (context: { label?: string; parsed: number }) => {
            return `${context.label || ''}: ${context.parsed} séances`;
          },
        },
      },
    },
  };

  return (
    <Card className="chart-container">
      <h2 className="chart-title">💰 État des paiements</h2>
      <div className="chart-wrapper">
        <Doughnut data={data} options={options} />
      </div>
    </Card>
  );
}

interface MonthlyChartProps {
  stats: MonthlyStats[];
}

export function MonthlyChart({ stats }: MonthlyChartProps) {
  const data = {
    labels: stats.map(s => s.month),
    datasets: [
      {
        label: 'C. Gigoux',
        data: stats.map(s => s.gigoux),
        backgroundColor: 'rgba(102, 126, 234, 0.7)',
        borderColor: 'rgba(102, 126, 234, 1)',
        borderWidth: 2,
        stack: 'stack0',
      },
      {
        label: 'L. Tindano',
        data: stats.map(s => s.tindano),
        backgroundColor: 'rgba(118, 75, 162, 0.7)',
        borderColor: 'rgba(118, 75, 162, 1)',
        borderWidth: 2,
        stack: 'stack0',
      },
    ],
  };

  const options = {
    ...commonOptions,
    scales: {
      x: {
        stacked: true,
        ticks: {
          font: { size: 10 },
          maxRotation: 45,
          minRotation: 45,
        },
        grid: { display: false },
      },
      y: {
        stacked: true,
        beginAtZero: true,
        ticks: {
          stepSize: 2,
          font: { size: 11 },
        },
        grid: { color: 'rgba(0,0,0,0.05)' },
      },
    },
  };

  return (
    <Card className="chart-container">
      <h2 className="chart-title">📈 Évolution mensuelle</h2>
      <div className="chart-wrapper chart-wrapper--tall">
        <Bar data={data} options={options} />
      </div>
    </Card>
  );
}

interface PractitionerChartProps {
  stats: PractitionerStats[];
}

export function PractitionerChart({ stats }: PractitionerChartProps) {
  const data = {
    labels: stats.map(s => s.name === 'C. Gigoux' ? 'Corentin Gigoux' : 'Léonard Tindano'),
    datasets: [
      {
        data: stats.map(s => s.count),
        backgroundColor: [
          'rgba(102, 126, 234, 0.85)',
          'rgba(118, 75, 162, 0.85)',
        ],
        borderWidth: 0,
      },
    ],
  };

  const options = {
    ...commonOptions,
    cutout: '65%',
    plugins: {
      ...commonOptions.plugins,
      legend: {
        ...commonOptions.plugins.legend,
        position: 'bottom' as const,
      },
      tooltip: {
        ...commonOptions.plugins.tooltip,
        callbacks: {
          label: (context: { label?: string; parsed: number; dataset: { data: number[] } }) => {
            const total = context.dataset.data.reduce((a, b) => a + b, 0);
            const percentage = Math.round((context.parsed / total) * 100);
            return `${context.label || ''}: ${context.parsed} séances (${percentage}%)`;
          },
        },
      },
    },
  };

  return (
    <Card className="chart-container">
      <h2 className="chart-title">👨‍⚕️ Répartition par praticien</h2>
      <div className="chart-wrapper">
        <Doughnut data={data} options={options} />
      </div>
    </Card>
  );
}
