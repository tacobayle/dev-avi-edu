
const API_PREREQUISITE0 = 'https://lab-vs.sa.vclass.local/api/checkPrerequisitesLab04';
const API_PREREQUISITE1 = 'https://lab-vs.sa.vclass.local/api/checkPrerequisitesLab06';
const API_APPLY = 'https://lab-vs.sa.vclass.local/api/lab46';

async function checkPrerequisites() {
    const statusCell0 = document.getElementById('statusCell0');
    const statusCell1 = document.getElementById('statusCell1');
    const configButton = document.getElementById('configButton');

    // Disable button initially
    if (configButton) {
        configButton.disabled = true;
        configButton.style.opacity = '0.5';
        configButton.style.cursor = 'not-allowed';
    }

    // Helper function to check a single prerequisite API
    async function checkPrerequisite(apiUrl, statusCell, apiName) {
        try {
            const response = await fetch(apiUrl, {
                method: 'POST',
                headers: {'Content-Type': 'application/json'}
            });

            if (response.ok) {
                // Success (200-299)
                statusCell.innerHTML = '<div class="success"></div>';
                return true;
            } else {
                // Error (4xx or 5xx)
                statusCell.innerHTML = '<div class="error"></div>';
                console.error(`${apiName} Error: HTTP Status ${response.status}`);
                return false;
            }
        } catch (error) {
            // Network Error
            console.error(`${apiName} request failed:`, error);
            statusCell.innerHTML = '<div class="error"></div>';
            return false;
        }
    }

    // Check both prerequisites in parallel
    const [result0, result1] = await Promise.all([
        checkPrerequisite(API_PREREQUISITE0, statusCell0, 'API_PREREQUISITE0'),
        checkPrerequisite(API_PREREQUISITE1, statusCell1, 'API_PREREQUISITE1')
    ]);

    // Enable button only if both prerequisites are successful
    if (configButton) {
        if (result0 && result1) {
            // Both APIs returned successful responses
            configButton.disabled = false;
            configButton.style.opacity = '1';
            configButton.style.cursor = 'pointer';
        } else {
            // At least one API failed
            configButton.disabled = true;
            configButton.style.opacity = '0.5';
            configButton.style.cursor = 'not-allowed';
        }
    }
}

// ====================================================================
// REUSABLE COPY FUNCTION (This part is correctly structured)
// ====================================================================


function setupCopyButton(buttonId, contentId) {
    const copyButton = document.getElementById(buttonId);
    const contentToCopy = document.getElementById(contentId);

    if (copyButton && contentToCopy) {
        copyButton.addEventListener('click', () => {
            const textToCopy = contentToCopy.innerText;

            navigator.clipboard.writeText(textToCopy)
                .then(() => {
                    // alert(`Content for ${contentId} copied successfully!`);
                    console.log(`Content from ${contentId} successfully copied.`);
                })
                .catch(err => {
                    console.error('Could not copy text: ', err);
                    alert('Failed to copy content. Please try again.');
                });
        });
    } else {
        // Log errors if the elements are missing in the HTML
        if (!copyButton) {
            console.error(`Copy Button with ID '${buttonId}' was not found.`);
        }
        if (!contentToCopy) {
            console.error(`Content Element with ID '${contentId}' was not found.`);
        }
    }
}

// ====================================================================
// MAIN EXECUTION BLOCK (Runs ONLY when the page is fully loaded)
// ====================================================================

document.addEventListener('DOMContentLoaded', checkPrerequisites);

document.addEventListener('DOMContentLoaded', () => {

    // --- 1. SETUP CONFIGURATION BUTTON (CLEANED UP) ---
    const myButton = document.getElementById('configButton');

    // Attach the click listener directly to the button, only once.
    if (myButton) {
        myButton.addEventListener('click', () => {
            // Prevent action if button is disabled
            if (myButton.disabled) {
                return;
            }

            fetch(API_APPLY, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
            })
            .then(response => {
                if (!response.ok) {
                    // Check for a specific API error response here if needed
                    throw new Error('Configuration failed');
                }
            })
            .then(data => {
                console.log('Success:', data);
                alert('Configuration applied');
            })
            .catch((error) => {
                console.log('Error:', error);
                alert('Configuration failed');
            });
        });
    } else {
        console.error("Configuration button with ID 'configButton' was not found.");
    }

    setupCopyButton('copyButton0', 'contentToCopy0');
    // --- 2. SETUP MULTIPLE COPY BUTTONS ---

    // Note: You must ensure 'quoteContent', 'summaryContent', etc., are the
    // correct IDs for the content areas in your HTML.
    // You had multiple setup calls for the same button IDs but different content
    // IDs in your previous code. I've updated these to match the IDs
    // in your provided HTML structure (contentToCopy0, contentToCopy1, etc.).
});