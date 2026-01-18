import { useState, useEffect, useCallback } from 'react';
import { fetchNui } from '../../utils/nui';
import { FinanceData, Transaction, EmployeeAccess } from '../../types';
import {
  DollarSign,
  TrendingUp,
  ArrowUpCircle,
  ArrowDownCircle,
  RefreshCw,
  Wallet,
  Calendar,
} from 'lucide-react';

interface FinancesProps {
  access: EmployeeAccess | null;
}

export default function Finances({ access: _access }: FinancesProps) {
  const [finances, setFinances] = useState<FinanceData | null>(null);
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [showWithdrawModal, setShowWithdrawModal] = useState(false);
  const [showDepositModal, setShowDepositModal] = useState(false);
  const [amount, setAmount] = useState('');
  const [processing, setProcessing] = useState(false);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    setLoading(true);
    const [finResult, txResult] = await Promise.all([
      fetchNui<FinanceData>('getFinances'),
      fetchNui<Transaction[]>('getTransactions'),
    ]);
    setFinances(finResult || null);
    setTransactions(txResult || []);
    setLoading(false);
  };

  const handleWithdraw = useCallback(async () => {
    const withdrawAmount = parseInt(amount, 10);
    if (isNaN(withdrawAmount) || withdrawAmount <= 0) return;
    if (finances && withdrawAmount > finances.balance) return;

    setProcessing(true);
    const result = await fetchNui<{ success: boolean; error?: string }>(
      'withdrawFunds',
      { amount: withdrawAmount }
    );

    if (result?.success) {
      setShowWithdrawModal(false);
      setAmount('');
      loadData();
    }
    setProcessing(false);
  }, [amount, finances]);

  const handleDeposit = useCallback(async () => {
    const depositAmount = parseInt(amount, 10);
    if (isNaN(depositAmount) || depositAmount <= 0) return;

    setProcessing(true);
    const result = await fetchNui<{ success: boolean; error?: string }>(
      'depositFunds',
      { amount: depositAmount }
    );

    if (result?.success) {
      setShowDepositModal(false);
      setAmount('');
      loadData();
    }
    setProcessing(false);
  }, [amount]);

  const formatCurrency = (value: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(value);
  };

  const formatDate = (dateStr: string) => {
    const date = new Date(dateStr);
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const getTransactionIcon = (type: string) => {
    switch (type) {
      case 'deposit':
        return <ArrowDownCircle size={18} className="tx-icon deposit" />;
      case 'withdrawal':
        return <ArrowUpCircle size={18} className="tx-icon withdrawal" />;
      case 'sale':
        return <DollarSign size={18} className="tx-icon sale" />;
      case 'stock_order':
        return <Wallet size={18} className="tx-icon expense" />;
      default:
        return <DollarSign size={18} className="tx-icon" />;
    }
  };

  if (loading) {
    return (
      <div className="loading-container">
        <div className="loading-spinner"></div>
        <p>Loading finances...</p>
      </div>
    );
  }

  return (
    <div className="finances-view">
      {/* Balance Card */}
      <div className="balance-card">
        <div className="balance-header">
          <span className="balance-label">Business Balance</span>
          <button className="btn btn-icon" onClick={loadData} title="Refresh">
            <RefreshCw size={16} />
          </button>
        </div>
        <div className="balance-amount">
          {formatCurrency(finances?.balance || 0)}
        </div>
        <div className="balance-actions">
          <button
            className="btn btn-success"
            onClick={() => setShowDepositModal(true)}
          >
            <ArrowDownCircle size={16} />
            Deposit
          </button>
          <button
            className="btn btn-warning"
            onClick={() => setShowWithdrawModal(true)}
            disabled={!finances?.balance || finances.balance <= 0}
          >
            <ArrowUpCircle size={16} />
            Withdraw
          </button>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="finance-stats">
        <div className="stat-card">
          <div className="stat-icon">
            <TrendingUp size={20} />
          </div>
          <div className="stat-content">
            <span className="stat-value">
              {formatCurrency(finances?.todaySales || 0)}
            </span>
            <span className="stat-label">Today's Sales</span>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon">
            <Calendar size={20} />
          </div>
          <div className="stat-content">
            <span className="stat-value">
              {formatCurrency(finances?.weekSales || 0)}
            </span>
            <span className="stat-label">This Week</span>
          </div>
        </div>
      </div>

      {/* Transaction History */}
      <div className="transactions-section">
        <h3 className="section-title">Recent Transactions</h3>
        {transactions.length === 0 ? (
          <div className="empty-state">
            <DollarSign size={32} />
            <p>No transactions yet.</p>
          </div>
        ) : (
          <div className="transaction-list">
            {transactions.map((tx, idx) => (
              <div key={idx} className="transaction-item">
                {getTransactionIcon(tx.type)}
                <div className="tx-info">
                  <span className="tx-description">{tx.description}</span>
                  <span className="tx-date">{formatDate(tx.date)}</span>
                </div>
                <span
                  className={`tx-amount ${tx.amount >= 0 ? 'positive' : 'negative'}`}
                >
                  {tx.amount >= 0 ? '+' : ''}
                  {formatCurrency(tx.amount)}
                </span>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Withdraw Modal */}
      {showWithdrawModal && (
        <div className="modal-overlay" onClick={() => setShowWithdrawModal(false)}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Withdraw Funds</h3>
              <button
                className="modal-close"
                onClick={() => setShowWithdrawModal(false)}
              >
                &times;
              </button>
            </div>
            <div className="modal-body">
              <div className="form-group">
                <label>Amount</label>
                <div className="input-with-icon">
                  <DollarSign size={16} />
                  <input
                    type="number"
                    className="form-input"
                    placeholder="0"
                    value={amount}
                    onChange={e => setAmount(e.target.value)}
                    max={finances?.balance || 0}
                  />
                </div>
                <span className="form-hint">
                  Available: {formatCurrency(finances?.balance || 0)}
                </span>
              </div>
              <div className="modal-actions">
                <button
                  className="btn btn-secondary"
                  onClick={() => setShowWithdrawModal(false)}
                >
                  Cancel
                </button>
                <button
                  className="btn btn-warning"
                  onClick={handleWithdraw}
                  disabled={
                    processing ||
                    !amount ||
                    parseInt(amount, 10) <= 0 ||
                    parseInt(amount, 10) > (finances?.balance || 0)
                  }
                >
                  {processing ? 'Processing...' : 'Withdraw'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Deposit Modal */}
      {showDepositModal && (
        <div className="modal-overlay" onClick={() => setShowDepositModal(false)}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Deposit Funds</h3>
              <button
                className="modal-close"
                onClick={() => setShowDepositModal(false)}
              >
                &times;
              </button>
            </div>
            <div className="modal-body">
              <div className="form-group">
                <label>Amount</label>
                <div className="input-with-icon">
                  <DollarSign size={16} />
                  <input
                    type="number"
                    className="form-input"
                    placeholder="0"
                    value={amount}
                    onChange={e => setAmount(e.target.value)}
                  />
                </div>
              </div>
              <div className="modal-actions">
                <button
                  className="btn btn-secondary"
                  onClick={() => setShowDepositModal(false)}
                >
                  Cancel
                </button>
                <button
                  className="btn btn-success"
                  onClick={handleDeposit}
                  disabled={processing || !amount || parseInt(amount, 10) <= 0}
                >
                  {processing ? 'Processing...' : 'Deposit'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
