import { StaffMember, EmployeeAccess } from '../../types';
import { RefreshCw, User, Shield } from 'lucide-react';

interface StaffListProps {
  staff: StaffMember[];
  access: EmployeeAccess | null;
  onRefresh: () => void;
}

export default function StaffList({
  staff,
  access,
  onRefresh,
}: StaffListProps) {
  const sortedStaff = [...staff].sort((a, b) => b.grade - a.grade);

  if (staff.length === 0) {
    return (
      <div className="main-content">
        <div className="section-header">
          <div className="section-title">Staff On Duty</div>
          <button className="refresh-btn" onClick={onRefresh}>
            <RefreshCw size={18} />
          </button>
        </div>
        <div className="empty-state">
          <User size={64} className="empty-icon" />
          <h3>No Staff On Duty</h3>
          <p>Staff members will appear here when they clock in</p>
        </div>
      </div>
    );
  }

  return (
    <div className="staff-list-view">
      <div className="section-header">
        <div className="section-title">
          Staff On Duty
          <span className="section-badge">{staff.length}</span>
        </div>
        <button className="refresh-btn" onClick={onRefresh}>
          <RefreshCw size={18} />
        </button>
      </div>

      <div className="staff-cards">
        {sortedStaff.map(member => {
          const isManager = member.grade >= 3;
          const isSelf = member.citizenid === access?.citizenid;

          return (
            <div
              key={member.citizenid}
              className={`staff-card ${isSelf ? 'staff-card-self' : ''}`}
            >
              <div className="staff-avatar-container">
                <div
                  className="staff-avatar"
                  style={{
                    background: isManager
                      ? 'var(--gradient-primary)'
                      : 'var(--surface-elevated)',
                  }}
                >
                  {member.name.charAt(0).toUpperCase()}
                </div>
                {isManager && (
                  <div className="staff-badge">
                    <Shield size={10} />
                  </div>
                )}
              </div>

              <div className="staff-info">
                <div className="staff-name">
                  {member.name}
                  {isSelf && <span className="staff-you-tag">You</span>}
                </div>
                <div className="staff-role">{member.gradeLabel}</div>
              </div>

              <div className="staff-status">
                <div className="staff-duty-indicator"></div>
                <span>On Duty</span>
              </div>
            </div>
          );
        })}
      </div>

      {/* Role Legend */}
      <div className="role-legend">
        <div className="role-legend-item">
          <Shield size={14} className="role-legend-icon manager" />
          <span>Manager+</span>
        </div>
        <div className="role-legend-item">
          <User size={14} className="role-legend-icon" />
          <span>Staff</span>
        </div>
      </div>
    </div>
  );
}
