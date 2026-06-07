const quickAmounts = [50000, 100000, 200000, 10000];
let appState = null;
let activeSection = "entry";

const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => [...document.querySelectorAll(selector)];

function formatWon(value) {
  return `${Number(value || 0).toLocaleString("ko-KR")}원`;
}

function formatNumber(value) {
  return Number(value || 0).toLocaleString("ko-KR");
}

function parseAmount(value) {
  return Number(String(value || "").replace(/[^0-9]/g, "") || 0);
}

function displayTime(value) {
  if (!value) return "";
  const date = new Date(String(value).replace(" ", "T"));
  if (Number.isNaN(date.getTime())) return value;
  const now = new Date();
  const sameDay = date.toDateString() === now.toDateString();
  const yesterday = new Date(now);
  yesterday.setDate(now.getDate() - 1);
  const day = sameDay ? "오늘" : date.toDateString() === yesterday.toDateString() ? "어제" : `${date.getMonth() + 1}/${date.getDate()}`;
  return `${day} ${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`;
}

async function api(path, options = {}) {
  const response = await fetch(path, {
    headers: { "Content-Type": "application/json", ...(options.headers || {}) },
    credentials: "same-origin",
    ...options,
  });
  if (options.raw) return response;
  const data = await response.json();
  if (!response.ok) {
    const error = new Error(data.error || "요청에 실패했습니다.");
    error.data = data;
    error.status = response.status;
    throw error;
  }
  return data;
}

function applyTheme(preference) {
  const prefersDark = window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
  const theme = preference === "dark" || (preference === "system" && prefersDark) ? "dark" : "light";
  document.body.dataset.theme = theme;
  $("#darkSwitch").checked = theme === "dark";
  $("#themeSelect").value = preference || "system";
}

function showAuth(configured) {
  $("#authOverlay").classList.remove("hidden");
  $("#passwordInput").value = "";
  $("#passwordConfirmInput").value = "";
  $("#recoveryBox").classList.add("hidden");
  if (configured) {
    $("#authTitle").textContent = "잠금 해제";
    $("#authDescription").textContent = "비밀번호를 입력해 축의대 장부를 엽니다.";
    $("#passwordConfirmInput").classList.add("hidden");
    $("#authButton").textContent = "로그인";
  } else {
    $("#authTitle").textContent = "축의대 장부 시작하기";
    $("#authDescription").textContent = "처음 사용할 비밀번호를 설정하세요.";
    $("#passwordConfirmInput").classList.remove("hidden");
    $("#authButton").textContent = "비밀번호 설정";
  }
}

function hideAuth() {
  $("#authOverlay").classList.add("hidden");
}

function switchSection(section) {
  activeSection = section;
  $$(".section").forEach((item) => item.classList.remove("active"));
  $(`#${section}Section`).classList.add("active");
  $$(".nav-item").forEach((item) => item.classList.toggle("active", item.dataset.section === section));
  if (section === "search") refreshSearch();
  if (section === "summary") renderSummary();
}

function fillDatalist(id, values) {
  const list = $(id);
  list.innerHTML = "";
  values.forEach((value) => {
    const option = document.createElement("option");
    option.value = value;
    list.append(option);
  });
}

function renderRecent(entries) {
  const body = $("#recentBody");
  body.innerHTML = "";
  const rows = entries.length ? entries : [];
  rows.forEach((entry) => {
    const row = document.createElement("tr");
    row.innerHTML = `
      <td>${entry.name}</td>
      <td>${entry.groupName}</td>
      <td>${entry.relationship || "-"}</td>
      <td class="amount-cell">${formatNumber(entry.amount)}</td>
      <td>${entry.mealTicketCount}</td>
      <td>${displayTime(entry.createdAt)}</td>
    `;
    body.append(row);
  });
  if (!rows.length) {
    body.innerHTML = `<tr><td colspan="6">아직 입력된 기록이 없습니다.</td></tr>`;
  }
}

function renderSummary() {
  const summary = appState?.summary;
  if (!summary) return;
  $("#totalAmount").textContent = formatWon(summary.totalAmount);
  $("#totalCount").textContent = `건수 ${summary.activeCount.toLocaleString("ko-KR")}건`;
  $("#totalTickets").textContent = `${summary.totalTickets.toLocaleString("ko-KR")}매`;
  $("#ticketDetail").textContent = `사용 ${summary.totalTickets.toLocaleString("ko-KR")}매 ㅣ 남은 0매`;
  const average = summary.activeCount ? Math.round(summary.totalAmount / summary.activeCount) : 0;
  $("#averageAmount").textContent = formatWon(average);

  const tiles = [
    ["정상 기록", `${summary.activeCount.toLocaleString("ko-KR")}건`],
    ["취소 기록", `${summary.voidCount.toLocaleString("ko-KR")}건`],
    ["현금 합계", formatWon(summary.paymentTotals.cash)],
    ["계좌 합계", formatWon(summary.paymentTotals.transfer)],
    ["기타 합계", formatWon(summary.paymentTotals.other)],
    ["누락 봉투", summary.envelopeGaps.length ? summary.envelopeGaps.join(", ") : "없음"],
    ["동명이인", summary.duplicateNames.length ? summary.duplicateNames.map((item) => item.name).join(", ") : "없음"],
  ];
  $("#summaryGrid").innerHTML = tiles.map(([label, value]) => `<div class="summary-tile"><span>${label}</span><strong>${value}</strong></div>`).join("");
  $("#groupSummaryBody").innerHTML = summary.groupTotals.length
    ? summary.groupTotals.map((item) => `<tr><td>${item.group_name}</td><td>${item.count}</td><td class="amount-cell">${formatWon(item.total_amount)}</td><td>${item.total_tickets}</td></tr>`).join("")
    : `<tr><td colspan="4">모임별 합계가 없습니다.</td></tr>`;
}

function renderState(state) {
  appState = state;
  applyTheme(state.themePreference || "system");
  if (!state.configured || !state.unlocked) {
    showAuth(state.configured);
    return;
  }
  hideAuth();
  $("#modeLabel").textContent = `${state.modeLabel} 모드`;
  $("#envelopeInput").value = state.nextEnvelopeNo;
  $("#groupInput").value = state.groups[0] || "미분류";
  fillDatalist("#groupList", state.groups || []);
  fillDatalist("#relationshipList", state.relationships || []);
  renderRecent(state.recentEntries || []);
  renderSummary();
}

async function refreshState() {
  const state = await api("/api/state");
  renderState(state);
}

async function submitAuth() {
  const password = $("#passwordInput").value;
  const confirm = $("#passwordConfirmInput").value;
  const configured = appState?.configured;
  if (!configured && password !== confirm) {
    alert("비밀번호 확인이 일치하지 않습니다.");
    return;
  }
  try {
    const state = await api(configured ? "/api/login" : "/api/setup", {
      method: "POST",
      body: JSON.stringify({ password }),
    });
    renderState(state);
    if (state.recoveryKey) {
      $("#recoveryBox").textContent = `복구키를 따로 보관하세요:\n${state.recoveryKey}`;
      $("#recoveryBox").classList.remove("hidden");
      alert(`복구키를 따로 보관하세요.\n${state.recoveryKey}`);
    }
  } catch (error) {
    alert(error.message);
  }
}

async function saveEntry(forceDuplicate = false) {
  const payload = {
    envelopeNo: $("#envelopeInput").value,
    name: $("#nameInput").value.trim(),
    groupName: $("#groupInput").value.trim(),
    relationship: $("#relationshipInput").value.trim(),
    amount: $("#amountInput").value,
    mealTicketCount: $("#ticketInput").value,
    paymentMethod: "cash",
    memo: $("#memoInput").value.trim(),
    forceDuplicate,
  };
  if (!payload.name || !parseAmount(payload.amount)) {
    alert("이름과 금액은 필수입니다.");
    return;
  }
  try {
    const result = await api("/api/entry", { method: "POST", body: JSON.stringify(payload) });
    renderState(result.state);
    $("#nameInput").value = "";
    $("#relationshipInput").value = "";
    $("#amountInput").value = "";
    $("#ticketInput").value = "0";
    $("#memoInput").value = "";
    $("#nameInput").focus();
  } catch (error) {
    if (error.status === 409 && confirm("같은 이름의 정상 기록이 있습니다. 그래도 저장할까요?")) {
      await saveEntry(true);
      return;
    }
    alert(error.message);
  }
}

async function refreshSearch() {
  const query = new URLSearchParams({
    name: $("#searchName").value,
    group: $("#searchGroup").value,
    minAmount: $("#searchMin").value,
    maxAmount: $("#searchMax").value,
  });
  const result = await api(`/api/entries?${query.toString()}`);
  $("#searchBody").innerHTML = result.entries.length
    ? result.entries.map((entry) => `
        <tr>
          <td>${entry.envelopeNo}</td>
          <td>${entry.name}</td>
          <td>${entry.groupName}</td>
          <td>${entry.relationship || "-"}</td>
          <td class="amount-cell">${formatWon(entry.amount)}</td>
          <td>${entry.mealTicketCount}</td>
          <td>${entry.status === "active" ? "정상" : "취소"}</td>
        </tr>
      `).join("")
    : `<tr><td colspan="7">검색 결과가 없습니다.</td></tr>`;
}

async function setMode(mode) {
  if (mode === "live" && !confirm("운영 모드에서는 실제 기록을 입력합니다. 전환할까요?")) return;
  const state = await api("/api/mode", { method: "POST", body: JSON.stringify({ mode }) });
  renderState(state);
}

async function setTheme(themePreference) {
  await api("/api/theme", { method: "POST", body: JSON.stringify({ themePreference }) });
  appState.themePreference = themePreference;
  applyTheme(themePreference);
}

async function resetData(kind) {
  const messages = {
    test: "테스트 모드 기록만 삭제합니다. 백업은 생성하지 않습니다.",
    records: "모든 기록과 모임/관계 목록을 삭제합니다. 비밀번호와 설정은 유지됩니다.",
    all: "기록, 모임/관계, 비밀번호, 복구키, 설정을 모두 삭제합니다. 처음 시작 상태로 돌아갑니다.",
  };
  if (!confirm(`${messages[kind]}\n계속할까요?`)) return;
  if (kind === "all" && !confirm("정말 전체 초기화할까요? 이 작업은 되돌릴 수 없습니다.")) return;
  const result = await api(`/api/reset/${kind}`, { method: "POST", body: "{}" });
  if (kind === "all") {
    appState = { configured: false, unlocked: false, themePreference: "system" };
    renderState(appState);
  } else {
    renderState(result.state);
  }
}

function bindEvents() {
  $$(".nav-item, [data-section-jump]").forEach((button) => {
    button.addEventListener("click", () => switchSection(button.dataset.section || button.dataset.sectionJump));
  });
  $("#authButton").addEventListener("click", submitAuth);
  $("#passwordInput").addEventListener("keydown", (event) => {
    if (event.key === "Enter") submitAuth();
  });
  $("#entryForm").addEventListener("submit", (event) => {
    event.preventDefault();
    saveEntry();
  });
  $("#amountInput").addEventListener("input", (event) => {
    const amount = parseAmount(event.target.value);
    event.target.value = amount ? formatNumber(amount) : "";
  });
  $("#ticketMinus").addEventListener("click", () => {
    $("#ticketInput").value = Math.max(0, Number($("#ticketInput").value || 0) - 1);
  });
  $("#ticketPlus").addEventListener("click", () => {
    $("#ticketInput").value = Number($("#ticketInput").value || 0) + 1;
  });
  $("#searchButton").addEventListener("click", refreshSearch);
  $("#testModeButton").addEventListener("click", () => setMode("test"));
  $("#liveModeButton").addEventListener("click", () => setMode("live"));
  $("#themeSelect").addEventListener("change", (event) => setTheme(event.target.value));
  $("#darkSwitch").addEventListener("change", (event) => setTheme(event.target.checked ? "dark" : "light"));
  $("#exportButton").addEventListener("click", () => {
    window.location.href = "/api/export";
  });
  $("#lockButton").addEventListener("click", async () => {
    await api("/api/lock", { method: "POST", body: "{}" });
    await refreshState();
  });
  $("#resetTestButton").addEventListener("click", () => resetData("test"));
  $("#resetRecordsButton").addEventListener("click", () => resetData("records"));
  $("#resetAllButton").addEventListener("click", () => resetData("all"));
  quickAmounts.forEach((amount) => {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = amount === 10000 ? "+1만원" : formatNumber(amount);
    if (amount === 10000) button.classList.add("plus");
    button.addEventListener("click", () => {
      const current = amount === 10000 ? parseAmount($("#amountInput").value) : 0;
      $("#amountInput").value = formatNumber(current + amount);
    });
    $("#quickAmounts").append(button);
  });
}

bindEvents();
refreshState().catch((error) => alert(error.message));
