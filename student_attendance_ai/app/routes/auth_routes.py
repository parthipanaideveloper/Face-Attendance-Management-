from flask import Blueprint, render_template, request, redirect, url_for, session

auth_bp = Blueprint('auth_bp', __name__)

@auth_bp.route('/login', methods=['GET', 'POST'])
def login():
    """Basic admin login route to protect sensitive views like Registration and Reports."""
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        # Simple hardcoded authentication for demonstration
        # In a real app, you would check a 'users' table in the database
        if username == 'admin' and password == 'admin123':
            session['logged_in'] = True
            return redirect(url_for('attendance_bp.dashboard'))
        else:
            return "Invalid Credentials. Try username: admin / password: admin123", 401
            
    return render_template('login.html')

@auth_bp.route('/logout')
def logout():
    """Logs out the user by clearing the session."""
    session.pop('logged_in', None)
    return redirect(url_for('auth_bp.login'))
