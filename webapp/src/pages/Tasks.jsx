import { FiPlus, FiFilter, FiCalendar, FiUser } from 'react-icons/fi'

const Tasks = () => {
  const tasks = [
    { id: 1, name: 'Review architectural plans', project: 'Modern Villa', assignee: 'John', dueDate: '2024-05-15', priority: 'high', status: 'in_progress' },
    { id: 2, name: 'Material selection approval', project: 'Office Renovation', assignee: 'Sarah', dueDate: '2024-05-10', priority: 'medium', status: 'pending' },
    { id: 3, name: 'Site inspection', project: 'Residential Complex', assignee: 'Mike', dueDate: '2024-05-08', priority: 'urgent', status: 'pending' },
  ]

  return (
    <div className="space-y-6 animate-fade-in">
      <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between">
        <div>
          <h1 className="text-2xl lg:text-3xl font-display font-bold text-gray-900">Tasks</h1>
          <p className="text-gray-600 mt-1">Manage and track all your tasks</p>
        </div>
        <button className="btn-primary mt-4 lg:mt-0 flex items-center space-x-2">
          <FiPlus className="w-5 h-5" />
          <span>New Task</span>
        </button>
      </div>

      <div className="card">
        <div className="space-y-4">
          {tasks.map((task) => (
            <div key={task.id} className="flex items-center justify-between p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition cursor-pointer">
              <div className="flex items-center space-x-4 flex-1">
                <input type="checkbox" className="w-5 h-5 text-primary-600 rounded" />
                <div className="flex-1">
                  <h4 className="font-medium text-gray-900">{task.name}</h4>
                  <div className="flex items-center space-x-4 mt-1 text-sm text-gray-600">
                    <span>{task.project}</span>
                    <span className="flex items-center space-x-1">
                      <FiUser className="w-4 h-4" />
                      <span>{task.assignee}</span>
                    </span>
                    <span className="flex items-center space-x-1">
                      <FiCalendar className="w-4 h-4" />
                      <span>{new Date(task.dueDate).toLocaleDateString()}</span>
                    </span>
                  </div>
                </div>
              </div>
              <div className="flex items-center space-x-3">
                <span className={`badge ${
                  task.priority === 'urgent' ? 'badge-danger' :
                  task.priority === 'high' ? 'badge-warning' :
                  'badge-primary'
                }`}>
                  {task.priority}
                </span>
                <span className={`badge ${
                  task.status === 'completed' ? 'badge-success' :
                  task.status === 'in_progress' ? 'badge-warning' :
                  'badge-gray'
                }`}>
                  {task.status}
                </span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

export default Tasks
