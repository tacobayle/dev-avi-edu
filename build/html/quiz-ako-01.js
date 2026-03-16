document.getElementById('quizForm').onsubmit = async (e) => {
    e.preventDefault();
    const formData = new FormData(e.target);
    const data = Object.fromEntries(formData.entries());

    // Handle multiple checkboxes specifically
    data.q2 = formData.getAll('q2');

    const response = await fetch('https://lab-vs.sa.vclass.local/api/quiz_ako_01', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify(data)
    });

    const result = await response.json();
    document.getElementById('result').innerText = "Your Grade: " + result.grade + "%";
};
