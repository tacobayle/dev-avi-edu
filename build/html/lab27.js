
const API_PREREQUISITE = 'https://lab-vs.sa.vclass.local/api/checkPrerequisitesLab06';
const API_APPLY = 'https://lab-vs.sa.vclass.local/api/lab27';

async function checkPrerequisites() {
    const statusCell = document.getElementById('statusCell');
    const configButton = document.getElementById('configButton');

    // Disable button initially
    if (configButton) {
        configButton.disabled = true;
        configButton.style.opacity = '0.5';
        configButton.style.cursor = 'not-allowed';
    }

    try {
        const response = await fetch(API_PREREQUISITE, {
            method: 'POST',
            headers: {'Content-Type': 'application/json'}
        });

        if (response.ok) {
            // Success (200-299)
            statusCell.innerHTML = '<div class="success"></div>';
            // Enable button on success
            if (configButton) {
                configButton.disabled = false;
                configButton.style.opacity = '1';
                configButton.style.cursor = 'pointer';
            }
        } else {
            // Error (4xx or 5xx)
            statusCell.innerHTML = '<div class="error"></div>';
            console.error(`API 1 Error: HTTP Status ${response.status}`);
            // Keep button disabled on error
            if (configButton) {
                configButton.disabled = true;
                configButton.style.opacity = '0.5';
                configButton.style.cursor = 'not-allowed';
            }
        }
    } catch (error) {
        // Network Error
        console.error('API request failed:', error);
        statusCell.innerHTML = '<div class="error"></div>';
        // Keep button disabled on error
        if (configButton) {
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
    setupCopyButton('copyButton1', 'contentToCopy1');
    setupCopyButton('copyButton2', 'contentToCopy2');
    setupCopyButton('copyButton3', 'contentToCopy3');
    setupCopyButton('copyButton4', 'contentToCopy4');
    setupCopyButton('copyButton5', 'contentToCopy5');
    setupCopyButton('copyButton6', 'contentToCopy6');
    setupCopyButton('copyButton7', 'contentToCopy7');

    // --- 2. SETUP MULTIPLE COPY BUTTONS ---

    // Note: You must ensure 'quoteContent', 'summaryContent', etc., are the
    // correct IDs for the content areas in your HTML.
    // You had multiple setup calls for the same button IDs but different content
    // IDs in your previous code. I've updated these to match the IDs
    // in your provided HTML structure (contentToCopy0, contentToCopy1, etc.).
});