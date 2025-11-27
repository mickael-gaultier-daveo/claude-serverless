import { useEffect, useState } from 'react';
import { X } from 'lucide-react';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  Title,
  Tooltip,
  Legend
} from 'chart.js';
import { Bar } from 'react-chartjs-2';
import { chatService } from '../services/chatService';

// Register Chart.js components
ChartJS.register(
  CategoryScale,
  LinearScale,
  BarElement,
  Title,
  Tooltip,
  Legend
);

interface UsageModalProps {
  isOpen: boolean;
  onClose: () => void;
}

interface MonthlyData {
  month: string;
  inputTokens: number;
  outputTokens: number;
  costUsd: number;
}

interface CurrentMonthUsage {
  month: string;
  inputTokens: number;
  outputTokens: number;
  costUsd: number;
}

export function UsageModal({ isOpen, onClose }: UsageModalProps) {
  const [monthlyData, setMonthlyData] = useState<MonthlyData[]>([]);
  const [currentMonthUsage, setCurrentMonthUsage] = useState<CurrentMonthUsage | null>(null);
  const [yearlyTotal, setYearlyTotal] = useState(0);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    if (isOpen) {
      loadData();
    }
  }, [isOpen]);

  const loadData = async () => {
    try {
      setIsLoading(true);
      
      // Charger les données du mois en cours
      const currentMonth = await chatService.getCurrentMonthUsage();
      setCurrentMonthUsage(currentMonth);
      
      // Charger les données mensuelles de l'année
      const monthlyResponse = await chatService.getMonthlyUsageYear();
      setMonthlyData(monthlyResponse.monthlyData);
      setYearlyTotal(monthlyResponse.totalCost);
    } catch (error) {
      console.error('Error loading usage data:', error);
    } finally {
      setIsLoading(false);
    }
  };

  if (!isOpen) return null;

  // Préparer tous les mois de l'année en cours
  const now = new Date();
  const year = now.getFullYear();
  const monthNames = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
  const allMonthsData: { month: string; costUsd: number }[] = [];
  const monthlyDataMap = new Map(monthlyData.map(d => [d.month, d.costUsd]));
  
  for (let m = 0; m < 12; m++) {
    const monthStr = `${year}-${String(m + 1).padStart(2, '0')}`;
    allMonthsData.push({
      month: monthStr,
      costUsd: monthlyDataMap.get(monthStr) || 0
    });
  }

  // Configuration du graphique mensuel
  const monthlyChartData = {
    labels: allMonthsData.map((_, idx) => `${monthNames[idx]} ${year}`),
    datasets: [
      {
        label: 'Coût mensuel ($)',
        data: allMonthsData.map(d => d.costUsd),
        backgroundColor: 'rgba(16, 185, 129, 0.5)',
        borderColor: 'rgb(16, 185, 129)',
        borderWidth: 1,
      },
    ],
  };

  const monthlyChartOptions = {
    responsive: true,
    plugins: {
      legend: {
        position: 'top' as const,
      },
      title: {
        display: true,
        text: 'Coûts mensuels de l\'année en cours',
      },
    },
    scales: {
      y: {
        beginAtZero: true,
        ticks: {
          callback: function(value: any) {
            return '$' + value.toFixed(2);
          }
        }
      }
    }
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-lg shadow-xl max-w-6xl w-full max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex justify-between items-center p-6 border-b border-gray-200 sticky top-0 bg-white z-10">
          <h2 className="text-2xl font-bold text-gray-900">Statistiques d'utilisation</h2>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
          >
            <X className="h-6 w-6 text-gray-500" />
          </button>
        </div>

        {/* Content */}
        <div className="p-6 space-y-8">
          {isLoading ? (
            <div className="flex justify-center items-center py-12">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
            </div>
          ) : (
            <>
              {/* Résumé du mois en cours */}
              <div className="mb-8">
                <div className="p-6 bg-blue-50 rounded-lg border border-blue-200">
                  <h3 className="text-xl font-semibold text-gray-800 mb-4">Mois en cours</h3>
                  <p className="text-center">
                    <span className="font-semibold text-gray-700">Coût total:</span>{' '}
                    <span className="text-3xl font-bold text-blue-600">
                      ${currentMonthUsage?.costUsd.toFixed(4) || '0.0000'}
                    </span>
                  </p>
                  <div className="mt-4 flex justify-center gap-8 text-sm text-gray-600">
                    <span>
                      Tokens entrée: {currentMonthUsage?.inputTokens.toLocaleString() || '0'}
                    </span>
                    <span>
                      Tokens sortie: {currentMonthUsage?.outputTokens.toLocaleString() || '0'}
                    </span>
                  </div>
                </div>
              </div>

              {/* Graphique annuel */}
              <div>
                <div className="bg-white p-6 rounded-lg border border-gray-200">
                  <Bar data={monthlyChartData} options={monthlyChartOptions} />
                </div>
                <div className="mt-4 p-4 bg-green-50 rounded-lg border border-green-200">
                  <p className="text-center text-lg">
                    <span className="font-semibold text-gray-700">Total de l'année:</span>{' '}
                    <span className="text-2xl font-bold text-green-600">${yearlyTotal.toFixed(2)}</span>
                  </p>
                  <div className="mt-2 flex justify-center gap-8 text-sm text-gray-600">
                    <span>
                      Tokens entrée: {monthlyData.reduce((sum, d) => sum + d.inputTokens, 0).toLocaleString()}
                    </span>
                    <span>
                      Tokens sortie: {monthlyData.reduce((sum, d) => sum + d.outputTokens, 0).toLocaleString()}
                    </span>
                  </div>
                </div>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
