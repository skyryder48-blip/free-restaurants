import { useState } from 'react';
import { EmployeeAccess, AppConfig } from '../../types';
import EmployeeList from './EmployeeList';
import Finances from './Finances';
import MenuPricing from './MenuPricing';
import StockOrdering from './StockOrdering';
import {
  Users,
  DollarSign,
  Tag,
  Package,
  ChevronLeft,
} from 'lucide-react';

interface ManagementViewProps {
  access: EmployeeAccess | null;
  config: AppConfig | null;
  onBack: () => void;
}

type ManagementTab = 'employees' | 'finances' | 'pricing' | 'stock';

export default function ManagementView({
  access,
  config: _config,
  onBack,
}: ManagementViewProps) {
  const [activeTab, setActiveTab] = useState<ManagementTab>('employees');

  if (!access?.canManage) {
    return (
      <div className="main-content">
        <div className="empty-state">
          <div className="empty-icon">
            <Users size={48} />
          </div>
          <h3>Access Denied</h3>
          <p>You don't have permission to access management features.</p>
          <button className="btn btn-primary" onClick={onBack}>
            Go Back
          </button>
        </div>
      </div>
    );
  }

  const tabs = [
    { id: 'employees' as const, label: 'Staff', icon: Users },
    { id: 'finances' as const, label: 'Finances', icon: DollarSign },
    { id: 'pricing' as const, label: 'Menu', icon: Tag },
    { id: 'stock' as const, label: 'Stock', icon: Package },
  ];

  const renderContent = () => {
    switch (activeTab) {
      case 'employees':
        return <EmployeeList access={access} />;
      case 'finances':
        return <Finances access={access} />;
      case 'pricing':
        return <MenuPricing access={access} />;
      case 'stock':
        return <StockOrdering access={access} />;
      default:
        return null;
    }
  };

  return (
    <div className="management-view">
      {/* Header */}
      <div className="management-header">
        <button className="back-btn" onClick={onBack}>
          <ChevronLeft size={20} />
        </button>
        <div className="management-title">
          <h2>Management</h2>
          <span className="management-subtitle">{access?.jobLabel}</span>
        </div>
      </div>

      {/* Tab Navigation */}
      <div className="management-tabs">
        {tabs.map(tab => (
          <button
            key={tab.id}
            className={`management-tab ${activeTab === tab.id ? 'active' : ''}`}
            onClick={() => setActiveTab(tab.id)}
          >
            <tab.icon size={16} />
            <span>{tab.label}</span>
          </button>
        ))}
      </div>

      {/* Content */}
      <div className="management-content">
        {renderContent()}
      </div>
    </div>
  );
}
