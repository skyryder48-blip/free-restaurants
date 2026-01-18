import { useState, useEffect, useCallback } from 'react';
import { fetchNui } from '../../utils/nui';
import { Employee, NearbyPlayer, JobGrade, EmployeeAccess } from '../../types';
import {
  UserPlus,
  UserMinus,
  ChevronUp,
  ChevronDown,
  RefreshCw,
  Search,
  Shield,
  User,
} from 'lucide-react';

interface EmployeeListProps {
  access: EmployeeAccess | null;
}

export default function EmployeeList({ access }: EmployeeListProps) {
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [nearbyPlayers, setNearbyPlayers] = useState<NearbyPlayer[]>([]);
  const [grades, setGrades] = useState<JobGrade[]>([]);
  const [loading, setLoading] = useState(true);
  const [showHireModal, setShowHireModal] = useState(false);
  const [selectedEmployee, setSelectedEmployee] = useState<Employee | null>(null);
  const [searchTerm, setSearchTerm] = useState('');

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    setLoading(true);
    const [empResult, gradeResult] = await Promise.all([
      fetchNui<Employee[]>('getEmployees'),
      fetchNui<JobGrade[]>('getJobGrades'),
    ]);
    setEmployees(empResult || []);
    setGrades(gradeResult || []);
    setLoading(false);
  };

  const loadNearbyPlayers = async () => {
    const result = await fetchNui<NearbyPlayer[]>('getNearbyPlayers');
    setNearbyPlayers(result || []);
  };

  const handleHire = useCallback(async (playerId: number, grade: number) => {
    const result = await fetchNui<{ success: boolean; error?: string }>(
      'hireEmployee',
      { playerId, grade }
    );

    if (result?.success) {
      setShowHireModal(false);
      loadData();
    }

    return result;
  }, []);

  const handleFire = useCallback(async (citizenid: string) => {
    if (!confirm('Are you sure you want to fire this employee?')) return;

    const result = await fetchNui<{ success: boolean; error?: string }>(
      'fireEmployee',
      { citizenid }
    );

    if (result?.success) {
      setSelectedEmployee(null);
      loadData();
    }

    return result;
  }, []);

  const handlePromote = useCallback(async (citizenid: string, newGrade: number) => {
    const result = await fetchNui<{ success: boolean; error?: string }>(
      'setEmployeeGrade',
      { citizenid, grade: newGrade }
    );

    if (result?.success) {
      loadData();
    }

    return result;
  }, []);

  const filteredEmployees = employees.filter(emp =>
    (emp.name || '').toLowerCase().includes(searchTerm.toLowerCase())
  );

  const getGradeColor = (grade: number) => {
    if (grade >= 5) return 'var(--accent)';
    if (grade >= 3) return 'var(--secondary)';
    if (grade >= 1) return 'var(--primary)';
    return 'var(--text-muted)';
  };

  const canModifyEmployee = (emp: Employee) => {
    if (!access?.grade) return false;
    // Can't modify self
    if (emp.citizenid === access.citizenid) return false;
    // Can only modify lower grades
    return emp.grade < access.grade;
  };

  return (
    <div className="employee-list-view">
      {/* Search and Actions Bar */}
      <div className="employee-actions">
        <div className="search-input-wrapper">
          <Search size={16} className="search-icon" />
          <input
            type="text"
            className="search-input"
            placeholder="Search employees..."
            value={searchTerm}
            onChange={e => setSearchTerm(e.target.value)}
          />
        </div>
        <div className="action-buttons">
          <button
            className="btn btn-icon"
            onClick={loadData}
            title="Refresh"
          >
            <RefreshCw size={18} />
          </button>
          <button
            className="btn btn-primary"
            onClick={() => {
              loadNearbyPlayers();
              setShowHireModal(true);
            }}
          >
            <UserPlus size={16} />
            <span>Hire</span>
          </button>
        </div>
      </div>

      {/* Employee Stats */}
      <div className="employee-stats">
        <div className="stat-card">
          <span className="stat-value">{employees.length}</span>
          <span className="stat-label">Total Staff</span>
        </div>
        <div className="stat-card">
          <span className="stat-value text-success">
            {employees.filter(e => e.online).length}
          </span>
          <span className="stat-label">Online</span>
        </div>
        <div className="stat-card">
          <span className="stat-value text-primary">
            {employees.filter(e => e.onduty).length}
          </span>
          <span className="stat-label">On Duty</span>
        </div>
      </div>

      {/* Employee List */}
      {loading ? (
        <div className="loading-container">
          <div className="loading-spinner"></div>
          <p>Loading employees...</p>
        </div>
      ) : filteredEmployees.length === 0 ? (
        <div className="empty-state">
          <User size={48} />
          <h3>No Employees Found</h3>
          <p>
            {searchTerm
              ? 'No employees match your search.'
              : 'Start by hiring some staff.'}
          </p>
        </div>
      ) : (
        <div className="employee-grid">
          {filteredEmployees.map(emp => (
            <div
              key={emp.citizenid}
              className={`employee-card ${selectedEmployee?.citizenid === emp.citizenid ? 'selected' : ''}`}
              onClick={() => setSelectedEmployee(emp)}
            >
              <div className="employee-avatar">
                <User size={24} />
                <span
                  className={`status-dot ${emp.online ? (emp.onduty ? 'on-duty' : 'online') : 'offline'}`}
                />
              </div>
              <div className="employee-info">
                <span className="employee-name">{emp.name}</span>
                <span
                  className="employee-grade"
                  style={{ color: getGradeColor(emp.grade) }}
                >
                  <Shield size={12} />
                  {emp.gradeLabel}
                </span>
              </div>
              {canModifyEmployee(emp) && (
                <div className="employee-actions-inline">
                  {emp.grade > 0 && (
                    <button
                      className="btn btn-icon btn-sm"
                      onClick={e => {
                        e.stopPropagation();
                        handlePromote(emp.citizenid, emp.grade - 1);
                      }}
                      title="Demote"
                    >
                      <ChevronDown size={16} />
                    </button>
                  )}
                  {emp.grade < (access?.grade || 0) - 1 && (
                    <button
                      className="btn btn-icon btn-sm"
                      onClick={e => {
                        e.stopPropagation();
                        handlePromote(emp.citizenid, emp.grade + 1);
                      }}
                      title="Promote"
                    >
                      <ChevronUp size={16} />
                    </button>
                  )}
                  <button
                    className="btn btn-icon btn-sm btn-danger"
                    onClick={e => {
                      e.stopPropagation();
                      handleFire(emp.citizenid);
                    }}
                    title="Fire"
                  >
                    <UserMinus size={16} />
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Hire Modal */}
      {showHireModal && (
        <div className="modal-overlay" onClick={() => setShowHireModal(false)}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Hire Employee</h3>
              <button
                className="modal-close"
                onClick={() => setShowHireModal(false)}
              >
                &times;
              </button>
            </div>
            <div className="modal-body">
              {nearbyPlayers.length === 0 ? (
                <div className="empty-state">
                  <User size={32} />
                  <p>No nearby players found.</p>
                  <button className="btn btn-secondary" onClick={loadNearbyPlayers}>
                    <RefreshCw size={14} />
                    Scan Again
                  </button>
                </div>
              ) : (
                <div className="nearby-players">
                  {nearbyPlayers.map(player => (
                    <div key={player.id} className="nearby-player-card">
                      <div className="player-info">
                        <span className="player-name">{player.name}</span>
                        <span className="player-distance">
                          {player.distance.toFixed(1)}m away
                        </span>
                        {player.isRestaurantEmployee && (
                          <span className="player-warning">
                            Already works at a restaurant
                          </span>
                        )}
                      </div>
                      {!player.isRestaurantEmployee && (
                        <div className="hire-grade-select">
                          <select
                            id={`grade-${player.id}`}
                            className="grade-select"
                            defaultValue="0"
                          >
                            {grades
                              .filter(g => g.level < (access?.grade || 0))
                              .map(grade => (
                                <option key={grade.level} value={grade.level}>
                                  {grade.name}
                                </option>
                              ))}
                          </select>
                          <button
                            className="btn btn-primary btn-sm"
                            onClick={() => {
                              const select = document.getElementById(
                                `grade-${player.id}`
                              ) as HTMLSelectElement;
                              handleHire(player.id, parseInt(select.value, 10));
                            }}
                          >
                            Hire
                          </button>
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
