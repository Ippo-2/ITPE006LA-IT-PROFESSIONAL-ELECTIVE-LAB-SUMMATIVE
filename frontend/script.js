const events = [
  {
    eventId: "harvest-fair",
    title: "Autumn Harvest Fair",
    eventDate: "2026-10-14",
    venue: "Founders Quad",
    seatsLeft: 42,
    imageColor: "#c6603d",
    imageDescription: "A campus fair illustration with autumn leaves and a golden sun."
  },
  {
    eventId: "poetry-night",
    title: "Open Mic Poetry Night",
    eventDate: "2026-10-21",
    venue: "Hawthorne Library, Reading Room",
    seatsLeft: 28,
    imageColor: "#406a82",
    imageDescription: "A reading-room illustration with a microphone and blue stage lights."
  },
  {
    eventId: "robotics-showcase",
    title: "Student Robotics Showcase",
    eventDate: "2026-10-29",
    venue: "Engineering Hall, Atrium",
    seatsLeft: 65,
    imageColor: "#537b55",
    imageDescription: "A robotics showcase illustration with a small campus-built robot."
  },
  {
    eventId: "film-screening",
    title: "Outdoor Film Screening",
    eventDate: "2026-11-06",
    venue: "Lakeside Lawn",
    seatsLeft: 90,
    imageColor: "#76547d",
    imageDescription: "An outdoor movie illustration with a screen beneath the evening sky."
  },
  {
    eventId: "winter-market",
    title: "Winter Makers Market",
    eventDate: "2026-11-18",
    venue: "Student Union, Main Hall",
    seatsLeft: 54,
    imageColor: "#377b78",
    imageDescription: "A makers market illustration with craft stalls and winter decorations."
  },
  {
    eventId: "music-showcase",
    title: "Campus Music Showcase",
    eventDate: "2026-12-02",
    venue: "Cedar Auditorium",
    seatsLeft: 110,
    imageColor: "#a65354",
    imageDescription: "A live music illustration with a guitar under warm stage lights."
  }
];

const attendees = [];
const catalog = document.querySelector("#eventCatalog");
const registrationForm = document.querySelector("#registrationForm");
const fullNameInput = document.querySelector("#fullName");
const emailInput = document.querySelector("#email");
const eventSelect = document.querySelector("#eventId");
const emailError = document.querySelector("#emailError");
const formError = document.querySelector("#formError");
const successMessage = document.querySelector("#successMessage");
const attendeeRows = document.querySelector("#attendeeRows");

function formatDate(eventDate) {
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    timeZone: "UTC"
  }).format(new Date(`${eventDate}T00:00:00Z`));
}

function makePlaceholderImage(event) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 320"><rect width="640" height="320" fill="${event.imageColor}"/><circle cx="510" cy="78" r="48" fill="#f4d58d"/><path d="M0 245 156 116l101 91 103-117 280 230H0Z" fill="#183532" opacity=".62"/><path d="M0 274 188 173l142 111 128-83 182 84v35H0Z" fill="#f0e9d7" opacity=".88"/></svg>`;
  return `data:image/svg+xml,${encodeURIComponent(svg)}`;
}

function renderEvents() {
  catalog.replaceChildren();

  for (const event of events) {
    const article = document.createElement("article");
    article.className = "event-card";

    const image = document.createElement("img");
    image.src = makePlaceholderImage(event);
    image.alt = event.imageDescription;
    image.loading = "lazy";

    const content = document.createElement("section");
    content.className = "event-card-content";

    const title = document.createElement("h3");
    title.textContent = event.title;

    const details = document.createElement("dl");
    const dateLabel = document.createElement("dt");
    dateLabel.textContent = "Date";
    const date = document.createElement("dd");
    const time = document.createElement("time");
    time.dateTime = event.eventDate;
    time.textContent = formatDate(event.eventDate);
    date.append(time);

    const venueLabel = document.createElement("dt");
    venueLabel.textContent = "Venue";
    const venue = document.createElement("dd");
    venue.textContent = event.venue;

    const seatsLabel = document.createElement("dt");
    seatsLabel.textContent = "Seats left";
    const seats = document.createElement("dd");
    seats.id = `seats-${event.eventId}`;
    seats.textContent = event.seatsLeft === 0 ? "Fully booked" : String(event.seatsLeft);

    details.append(dateLabel, date, venueLabel, venue, seatsLabel, seats);
    content.append(title, details);
    article.append(image, content);
    catalog.append(article);
  }
}

function updateEventOptions() {
  const selectedEventId = eventSelect.value;
  eventSelect.replaceChildren(new Option("Choose an event", ""));

  for (const event of events) {
    const option = new Option(
      `${event.title} - ${formatDate(event.eventDate)} (${event.seatsLeft} seats left)`,
      event.eventId
    );
    option.disabled = event.seatsLeft === 0;
    eventSelect.add(option);
  }

  if (events.some((event) => event.eventId === selectedEventId && event.seatsLeft > 0)) {
    eventSelect.value = selectedEventId;
  }
}

function clearMessages() {
  emailError.textContent = "";
  emailError.hidden = true;
  emailInput.removeAttribute("aria-invalid");
  formError.textContent = "";
  formError.hidden = true;
  successMessage.textContent = "";
  successMessage.hidden = true;
}

function showFormError(message) {
  formError.textContent = message;
  formError.hidden = false;
}

function renderAttendees() {
  attendeeRows.replaceChildren();

  if (attendees.length === 0) {
    const row = document.createElement("tr");
    row.className = "empty-row";
    const cell = document.createElement("td");
    cell.colSpan = 3;
    cell.textContent = "No registrations yet.";
    row.append(cell);
    attendeeRows.append(row);
    return;
  }

  for (const attendee of attendees) {
    const event = events.find((item) => item.eventId === attendee.eventId);
    const row = document.createElement("tr");

    for (const value of [attendee.fullName, attendee.email, event.title]) {
      const cell = document.createElement("td");
      cell.textContent = value;
      row.append(cell);
    }

    attendeeRows.append(row);
  }
}

emailInput.addEventListener("input", () => {
  emailError.textContent = "";
  emailError.hidden = true;
  emailInput.removeAttribute("aria-invalid");
});

registrationForm.addEventListener("submit", (event) => {
  event.preventDefault();
  clearMessages();

  const fullName = fullNameInput.value.trim();
  const email = emailInput.value.trim();
  const eventId = eventSelect.value;
  emailInput.value = email;

  if (!fullName) {
    showFormError("Enter your full name to register.");
    fullNameInput.focus();
    return;
  }

  if (!email || !emailInput.validity.valid) {
    emailInput.setAttribute("aria-invalid", "true");
    emailError.textContent = "Enter a valid student email address, such as name@campus.edu.";
    emailError.hidden = false;
    emailInput.focus();
    return;
  }

  const selectedEvent = events.find((item) => item.eventId === eventId);
  if (!selectedEvent) {
    showFormError("Choose an event before registering.");
    eventSelect.focus();
    return;
  }

  if (selectedEvent.seatsLeft === 0) {
    showFormError("That event is full. Choose another event.");
    updateEventOptions();
    eventSelect.focus();
    return;
  }

  attendees.push({ fullName, email, eventId });
  selectedEvent.seatsLeft -= 1;
  renderEvents();
  updateEventOptions();
  renderAttendees();
  registrationForm.reset();
  successMessage.textContent = `Registration confirmed for ${fullName} at ${selectedEvent.title}. ${selectedEvent.seatsLeft} seats remain.`;
  successMessage.hidden = false;
  successMessage.focus();
});

renderEvents();
updateEventOptions();
renderAttendees();
