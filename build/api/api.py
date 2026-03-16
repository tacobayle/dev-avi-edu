from flask import Flask, request, jsonify
import subprocess
import json
from flask_restful import Api, Resource, reqparse, abort
from flask_cors import CORS

# Creating a Flask app
app = Flask(__name__)
cors = CORS(app)

@app.route('/api/lab08', methods=['POST'])
def lab08():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'lab08.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/lab13', methods=['POST'])
def lab13():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'lab13.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/lab15', methods=['POST'])
def lab15():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'lab15.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/lab16', methods=['POST'])
def lab16():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'lab16.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/lab18', methods=['POST'])
def lab18():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'lab18.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/lab20', methods=['POST'])
def lab20():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'lab20.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/lab22', methods=['POST'])
def lab22():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'lab22.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/lab25', methods=['POST'])
def lab25():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'lab25.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/lab26', methods=['POST'])
def lab26():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'lab26.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/lab27', methods=['POST'])
def lab27():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'lab27.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/lab28', methods=['POST'])
def lab28():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'lab28.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/lab29', methods=['POST'])
def lab29():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'lab29.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/lab30', methods=['POST'])
def lab30():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'lab30.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/lab32', methods=['POST'])
def lab32():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'lab32.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/lab36', methods=['POST'])
def lab36():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'lab36.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/lab37', methods=['POST'])
def lab37():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'lab37.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/initializeYourVs', methods=['POST'])
def initializeYourVs():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'initializeYourVs.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/tshootTlsVsPool', methods=['POST'])
def tshootTlsVsPool():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'tshootTlsVsPool.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/tshootIntermittentVs01', methods=['POST'])
def tshootIntermittentVs01():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'tshootIntermittentVs01.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/tshootIntermittentVs02', methods=['POST'])
def tshootIntermittentVs02():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'tshootIntermittentVs02.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/gslbInfrastructureSiteB', methods=['POST'])
def gslbInfrastructureSiteB():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'gslbInfrastructureSiteB.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/tshootGslbService', methods=['POST'])
def tshootGslbService():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'tshootGslbService.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/authLdapVs', methods=['POST'])
def authLdapVs():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'authLdapVs.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/tshootPoolAuth', methods=['POST'])
def tshootPoolAuth():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'tshootPoolAuth.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/lab45', methods=['POST'])
def lab45():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'lab45.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/lab42', methods=['POST'])
def lab42():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'lab42.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/lab43', methods=['POST'])
def lab43():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'lab43.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/lab44', methods=['POST'])
def lab44():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'lab44.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/lab46', methods=['POST'])
def lab46():
    folder="/build/bash"
    process = subprocess.Popen(['/bin/bash', 'lab46.sh'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
    return "Config. applied", 201

@app.route('/api/checkPrerequisitesLab04', methods=['POST'])
def checkPrerequisitesLab04():
    process = subprocess.run(['/bin/bash', '/build/bash/checkPrerequisitesLab04.sh'], capture_output=True, text=True)
    if process.returncode == 0:
      return "Config. applied", 201
    else:
      return "Prereq. failed", 404

@app.route('/api/checkPrerequisitesLab06', methods=['POST'])
def checkPrerequisitesLab06():
    process = subprocess.run(['/bin/bash', '/build/bash/checkPrerequisitesLab06.sh'], capture_output=True, text=True)
    if process.returncode == 0:
      return "Config. applied", 201
    else:
      return "Prereq. failed", 404

@app.route('/api/checkPrerequisitesLab09', methods=['POST'])
def checkPrerequisitesLab09():
    process = subprocess.run(['/bin/bash', '/build/bash/checkPrerequisitesLab09.sh'], capture_output=True, text=True)
    if process.returncode == 0:
      return "Config. applied", 201
    else:
      return "Prereq. failed", 404

@app.route('/api/checkPrerequisitesLab32', methods=['POST'])
def checkPrerequisitesLab32():
    process = subprocess.run(['/bin/bash', '/build/bash/checkPrerequisitesLab32.sh'], capture_output=True, text=True)
    if process.returncode == 0:
      return "Config. applied", 201
    else:
      return "Prereq. failed", 404

@app.route('/api/checkPrerequisitesLab33', methods=['POST'])
def checkPrerequisitesLab33():
    process = subprocess.run(['/bin/bash', '/build/bash/checkPrerequisitesLab33.sh'], capture_output=True, text=True)
    if process.returncode == 0:
      return "Config. applied", 201
    else:
      return "Prereq. failed", 404

@app.route('/api/quizTest', methods=['POST'])
def quizTest():
    answers = request.json
    score = 0
    total_questions = 4 # Update this to 10 when you finish the HTML
    # Question 1 logic
    if answers.get('q1') == 'Paris':
        score += 1
    # Question 2 logic (Checkboxes)
    q2_answers = answers.get('q2', [])
    if 'Python' in q2_answers and 'Java' in q2_answers and 'HTML' not in q2_answers:
        score += 1
    # Question 3 logic
    if answers.get('q3') == '10':
        score += 1
    # Question 5 logic
    if answers.get('q5') == 'Mars':
        score += 1
    # Calculate percentage
    grade = (score / total_questions) * 100
    return jsonify({"grade": grade})

@app.route('/api/quiz_ako_01', methods=['POST'])
def quiz_ako_01():
    answers = request.json
    score = 0
    total_questions = 5 # Update this to 10 when you finish the HTML
    # Question 1
    if answers.get('q1') == 'ako':
        score += 1
    # Question 2
    q2_answers = answers.get('q2', [])
    if 'Default-Group-provider' in q2_answers and 'crd' in q2_answers and 'Default-Group-tenant' not in q2_answers:
        score += 1
    # Question 3
    if answers.get('q3') == 'node-ip':
        score += 1
    # Question 4
    if answers.get('q4') == 'vCenter':
        score += 1
    # Question 5
    if answers.get('q5') == 'true':
        score += 1
    # Calculate percentage
    grade = (score / total_questions) * 100
    return jsonify({"grade": grade})

# Start the server
if __name__ == '__main__':
    app.run()