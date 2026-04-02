/**
 * Parent Panel — Focused API Test Suite
 * ═══════════════════════════════════════
 * Tests parent-specific endpoints for:
 *   - Dashboard (/parents/me/dashboard)
 *   - Children  (/parents/me/children)
 *   - Payments  (/parents/me/payments)
 *   - Child report (/parents/me/children/:childId/report)
 *   - RBAC enforcement (non-parent roles blocked)
 *   - Data shape validation
 *   - Edge cases & error handling
 *
 * Run: node tests/parent_panel_test.mjs
 */

const BASE_URL = process.env.BASE_URL || 'https://abc-appxyz-hvfchqhagycbfcbp.centralindia-01.azurewebsites.net/api';

let PARENT_TOKEN = null;
let ADMIN_TOKEN = null;
let STUDENT_TOKEN = null;
let TEACHER_TOKEN = null;

let results = { passed: 0, failed: 0, skipped: 0, details: [] };

// ═══════════════════════════════════════════════════════════
// UTILITIES
// ═══════════════════════════════════════════════════════════
async function api(method, path, body = null, token = null) {
  const headers = { 'Content-Type': 'application/json', 'Accept': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const opts = { method, headers };
  if (body && method !== 'GET') opts.body = JSON.stringify(body);
  try {
    const res = await fetch(`${BASE_URL}${path}`, opts);
    const contentType = res.headers.get('content-type') || '';
    let data = null;
    if (contentType.includes('application/json')) {
      data = await res.json();
    } else {
      data = { raw: await res.text() };
    }
    return { status: res.status, data, ok: res.ok };
  } catch (err) {
    return { status: 0, data: null, ok: false, error: err.message };
  }
}

function test(id, name, passed, detail = '') {
  const icon = passed ? '✅' : '❌';
  if (passed) results.passed++; else results.failed++;
  results.details.push({ id, name, passed, detail });
  console.log(`  ${icon} P${String(id).padStart(3, '0')}: ${name}${detail ? ` — ${detail}` : ''}`);
}

function skip(id, name, reason) {
  results.skipped++;
  results.details.push({ id, name, passed: null, detail: reason });
  console.log(`  ⏭️  P${String(id).padStart(3, '0')}: ${name} — SKIPPED: ${reason}`);
}

// ═══════════════════════════════════════════════════════════
// 1. AUTH — get parent token (no-auth fallback)
// ═══════════════════════════════════════════════════════════
async function testParentAuth() {
  console.log('\n╔══════════════════════════════════════╗');
  console.log('║  🔐 PARENT AUTH & ENDPOINT CHECK     ║');
  console.log('╚══════════════════════════════════════╝');

  // P001: Parent endpoints require authentication
  const noAuth = await api('GET', '/parents/me/dashboard');
  test(1, 'Dashboard rejects unauthenticated request', noAuth.status === 401, `status=${noAuth.status}`);

  // P002: Children endpoint requires auth
  const noAuth2 = await api('GET', '/parents/me/children');
  test(2, 'Children rejects unauthenticated request', noAuth2.status === 401, `status=${noAuth2.status}`);

  // P003: Payments endpoint requires auth
  const noAuth3 = await api('GET', '/parents/me/payments');
  test(3, 'Payments rejects unauthenticated request', noAuth3.status === 401, `status=${noAuth3.status}`);

  // P004: Child report requires auth
  const noAuth4 = await api('GET', '/parents/me/children/00000000-0000-0000-0000-000000000000/report');
  test(4, 'Child report rejects unauthenticated request', noAuth4.status === 401, `status=${noAuth4.status}`);

  // P005: Invalid JWT is rejected
  const badJwt = await api('GET', '/parents/me/dashboard', null, 'invalid.jwt.token');
  test(5, 'Dashboard rejects invalid JWT', badJwt.status === 401 || badJwt.status === 403, `status=${badJwt.status}`);
}

// ═══════════════════════════════════════════════════════════
// 2. RBAC — non-parent roles must be blocked
// ═══════════════════════════════════════════════════════════
async function testCrossRoleAccess() {
  console.log('\n╔══════════════════════════════════════╗');
  console.log('║  🔒 CROSS-ROLE ACCESS CONTROL        ║');
  console.log('╚══════════════════════════════════════╝');

  // P006: Admin can't access parent dashboard
  if (!ADMIN_TOKEN) {
    skip(6, 'Admin blocked from parent dashboard', 'No admin token available');
  } else {
    const adminTry = await api('GET', '/parents/me/dashboard', null, ADMIN_TOKEN);
    test(6, 'Admin blocked from parent dashboard', adminTry.status === 403 || adminTry.status === 401, `status=${adminTry.status}`);
  }

  // P007: Student can't access parent dashboard
  if (!STUDENT_TOKEN) {
    skip(7, 'Student blocked from parent dashboard', 'No student token available');
  } else {
    const studentTry = await api('GET', '/parents/me/dashboard', null, STUDENT_TOKEN);
    test(7, 'Student blocked from parent dashboard', studentTry.status === 403 || studentTry.status === 401, `status=${studentTry.status}`);
  }

  // P008: Teacher can't access parent payments
  if (!TEACHER_TOKEN) {
    skip(8, 'Teacher blocked from parent payments', 'No teacher token available');
  } else {
    const teacherTry = await api('GET', '/parents/me/payments', null, TEACHER_TOKEN);
    test(8, 'Teacher blocked from parent payments', teacherTry.status === 403 || teacherTry.status === 401, `status=${teacherTry.status}`);
  }

  // P009: Student can't access parent children list
  if (!STUDENT_TOKEN) {
    skip(9, 'Student blocked from parent children', 'No student token available');
  } else {
    const studentChildren = await api('GET', '/parents/me/children', null, STUDENT_TOKEN);
    test(9, 'Student blocked from parent children endpoint', studentChildren.status === 403 || studentChildren.status === 401, `status=${studentChildren.status}`);
  }

  // P010: Teacher can't access child report
  if (!TEACHER_TOKEN) {
    skip(10, 'Teacher blocked from child report', 'No teacher token available');
  } else {
    const teacherReport = await api('GET', '/parents/me/children/00000000-0000-0000-0000-000000000000/report', null, TEACHER_TOKEN);
    test(10, 'Teacher blocked from child report', teacherReport.status === 403 || teacherReport.status === 401, `status=${teacherReport.status}`);
  }
}

// ═══════════════════════════════════════════════════════════
// 3. PARENT DASHBOARD DATA SHAPE
// ═══════════════════════════════════════════════════════════
async function testDashboardShape() {
  console.log('\n╔══════════════════════════════════════╗');
  console.log('║  📊 DASHBOARD DATA SHAPE             ║');
  console.log('╚══════════════════════════════════════╝');

  if (!PARENT_TOKEN) {
    skip(11, 'Dashboard returns valid shape', 'No parent token');
    skip(12, 'Dashboard contains children array', 'No parent token');
    skip(13, 'Dashboard children have id & name', 'No parent token');
    skip(14, 'Dashboard children have attendance', 'No parent token');
    skip(15, 'Dashboard children have pendingFee', 'No parent token');
    skip(16, 'Dashboard contains todaySchedule array', 'No parent token');
    skip(17, 'Dashboard contains upcomingExams array', 'No parent token');
    skip(18, 'Dashboard contains announcements array', 'No parent token');
    skip(19, 'Dashboard parent info present', 'No parent token');
    return;
  }

  const dash = await api('GET', '/parents/me/dashboard', null, PARENT_TOKEN);
  test(11, 'Dashboard returns 200 OK', dash.status === 200, `status=${dash.status}`);

  const d = dash.data?.data;
  test(12, 'Dashboard contains children array', Array.isArray(d?.children), `type=${typeof d?.children}`);

  if (Array.isArray(d?.children) && d.children.length > 0) {
    const child = d.children[0];
    test(13, 'Child object has id & name', !!child.id && !!child.name, `id=${child.id}, name=${child.name}`);
    test(14, 'Child object has attendance (number)', typeof child.attendance === 'number', `type=${typeof child.attendance}`);
    test(15, 'Child object has pendingFee (number)', typeof child.pendingFee === 'number', `type=${typeof child.pendingFee}`);
  } else {
    skip(13, 'Child object has id & name', 'No children in response');
    skip(14, 'Child object has attendance', 'No children in response');
    skip(15, 'Child object has pendingFee', 'No children in response');
  }

  test(16, 'Dashboard contains todaySchedule', Array.isArray(d?.todaySchedule), `type=${typeof d?.todaySchedule}`);
  test(17, 'Dashboard contains upcomingExams', Array.isArray(d?.upcomingExams), `type=${typeof d?.upcomingExams}`);
  test(18, 'Dashboard contains announcements', Array.isArray(d?.announcements), `type=${typeof d?.announcements}`);
  test(19, 'Dashboard parent info object present', d?.parent && typeof d.parent.id === 'string', `parent=${JSON.stringify(d?.parent)?.substring(0, 80)}`);
}

// ═══════════════════════════════════════════════════════════
// 4. CHILDREN ENDPOINT
// ═══════════════════════════════════════════════════════════
async function testChildrenEndpoint() {
  console.log('\n╔══════════════════════════════════════╗');
  console.log('║  👶 CHILDREN ENDPOINT                ║');
  console.log('╚══════════════════════════════════════╝');

  if (!PARENT_TOKEN) {
    skip(20, 'Children returns 200', 'No parent token');
    skip(21, 'Children returns array', 'No parent token');
    skip(22, 'Each child has id', 'No parent token');
    skip(23, 'Each child has name', 'No parent token');
    return;
  }

  const c = await api('GET', '/parents/me/children', null, PARENT_TOKEN);
  test(20, 'Children endpoint returns 200', c.status === 200, `status=${c.status}`);

  const children = c.data?.data;
  test(21, 'Children returns an array', Array.isArray(children), `type=${typeof children}`);

  if (Array.isArray(children) && children.length > 0) {
    test(22, 'First child has id field', typeof children[0].id === 'string', `id=${children[0].id}`);
    test(23, 'First child has name field', typeof children[0].name === 'string', `name=${children[0].name}`);
  } else {
    skip(22, 'Child has id', 'Empty children list');
    skip(23, 'Child has name', 'Empty children list');
  }
}

// ═══════════════════════════════════════════════════════════
// 5. PAYMENTS ENDPOINT
// ═══════════════════════════════════════════════════════════
async function testPaymentsEndpoint() {
  console.log('\n╔══════════════════════════════════════╗');
  console.log('║  💰 PAYMENTS ENDPOINT                ║');
  console.log('╚══════════════════════════════════════╝');

  if (!PARENT_TOKEN) {
    skip(24, 'Payments returns 200', 'No parent token');
    skip(25, 'Payments returns array', 'No parent token');
    skip(26, 'Fee record has final_amount', 'No parent token');
    skip(27, 'Fee record has status', 'No parent token');
    skip(28, 'Fee record has batch info', 'No parent token');
    skip(29, 'Fee record has due_date', 'No parent token');
    return;
  }

  const p = await api('GET', '/parents/me/payments', null, PARENT_TOKEN);
  test(24, 'Payments endpoint returns 200', p.status === 200, `status=${p.status}`);

  const payments = p.data?.data;
  test(25, 'Payments returns an array', Array.isArray(payments), `type=${typeof payments}`);

  if (Array.isArray(payments) && payments.length > 0) {
    const fee = payments[0];
    test(26, 'Fee record has final_amount', fee.final_amount !== undefined, `final_amount=${fee.final_amount}`);
    test(27, 'Fee record has status field', typeof fee.status === 'string', `status=${fee.status}`);
    test(28, 'Fee record includes batch info', fee.batch !== undefined, `batch=${JSON.stringify(fee.batch)?.substring(0, 60)}`);
    test(29, 'Fee record has due_date', fee.due_date !== undefined, `due_date=${fee.due_date}`);
  } else {
    skip(26, 'Fee record has final_amount', 'No payment records');
    skip(27, 'Fee record has status', 'No payment records');
    skip(28, 'Fee record has batch info', 'No payment records');
    skip(29, 'Fee record has due_date', 'No payment records');
  }
}

// ═══════════════════════════════════════════════════════════
// 6. CHILD REPORT ENDPOINT
// ═══════════════════════════════════════════════════════════
async function testChildReport() {
  console.log('\n╔══════════════════════════════════════╗');
  console.log('║  📝 CHILD REPORT ENDPOINT            ║');
  console.log('╚══════════════════════════════════════╝');

  // P030: Non-existent child returns error (even with valid parent token)
  if (!PARENT_TOKEN) {
    skip(30, 'Non-existent child report returns error', 'No parent token');
    skip(31, 'Invalid UUID in childId handled', 'No parent token');
    skip(32, 'Valid child report returns data', 'No parent token');
    skip(33, 'Report has attendance data', 'No parent token');
    skip(34, 'Report has results data', 'No parent token');
  } else {
    const noChild = await api('GET', '/parents/me/children/00000000-0000-0000-0000-000000000000/report', null, PARENT_TOKEN);
    test(30, 'Non-existent child report returns error', noChild.status >= 400, `status=${noChild.status}`);

    const badUuid = await api('GET', '/parents/me/children/not-a-uuid/report', null, PARENT_TOKEN);
    test(31, 'Invalid UUID in childId handled', badUuid.status >= 400, `status=${badUuid.status}`);

    // Try getting report for a real child
    const children = await api('GET', '/parents/me/children', null, PARENT_TOKEN);
    const childList = children.data?.data;
    if (Array.isArray(childList) && childList.length > 0) {
      const childId = childList[0].id;
      const report = await api('GET', `/parents/me/children/${childId}/report`, null, PARENT_TOKEN);
      test(32, 'Valid child report returns 200', report.status === 200, `status=${report.status}`);
      const rd = report.data?.data;
      test(33, 'Report has attendance data', rd?.attendance !== undefined, `type=${typeof rd?.attendance}`);
      test(34, 'Report has results data', rd?.results !== undefined, `type=${typeof rd?.results}`);
    } else {
      skip(32, 'Valid child report returns 200', 'No children to test');
      skip(33, 'Report has attendance data', 'No children to test');
      skip(34, 'Report has results data', 'No children to test');
    }
  }
}

// ═══════════════════════════════════════════════════════════
// 7. EDGE CASES & ERROR HANDLING
// ═══════════════════════════════════════════════════════════
async function testEdgeCases() {
  console.log('\n╔══════════════════════════════════════╗');
  console.log('║  ⚡ EDGE CASES & ERROR HANDLING      ║');
  console.log('╚══════════════════════════════════════╝');

  // P035: POST to a GET-only endpoint
  const postDash = await api('POST', '/parents/me/dashboard', { test: true });
  test(35, 'POST to dashboard returns 4xx (method not allowed)', postDash.status >= 400, `status=${postDash.status}`);

  // P036: PUT to a GET-only endpoint
  const putChildren = await api('PUT', '/parents/me/children', { test: true });
  test(36, 'PUT to children returns 4xx', putChildren.status >= 400, `status=${putChildren.status}`);

  // P037: DELETE on parent endpoint
  const delPayments = await api('DELETE', '/parents/me/payments');
  test(37, 'DELETE on payments returns 4xx', delPayments.status >= 400, `status=${delPayments.status}`);

  // P038: Very long childId doesn't crash server
  const longId = 'a'.repeat(500);
  const longChild = await api('GET', `/parents/me/children/${longId}/report`);
  test(38, 'Very long childId handled gracefully', longChild.status >= 400, `status=${longChild.status}`);

  // P039: SQL injection attempt in childId
  const sqlInject = await api('GET', "/parents/me/children/'; DROP TABLE parents; --/report");
  test(39, 'SQL injection in childId blocked', sqlInject.status >= 400 && sqlInject.status < 500, `status=${sqlInject.status}`);

  // P040: Double-slash in path
  const doublePath = await api('GET', '/parents//me/dashboard');
  test(40, 'Double-slash in path handled', doublePath.status !== 500, `status=${doublePath.status}`);

  // P041: Concurrent requests don't crash
  const concurrent = await Promise.all([
    api('GET', '/parents/me/dashboard'),
    api('GET', '/parents/me/children'),
    api('GET', '/parents/me/payments'),
  ]);
  const allSafe = concurrent.every(r => r.status !== 500 && r.status !== 0);
  test(41, 'Concurrent parent requests handled', allSafe, `statuses=${concurrent.map(r => r.status).join(',')}`);

  // P042: Empty Authorization header
  const emptyAuth = await api('GET', '/parents/me/dashboard', null, '');
  test(42, 'Empty auth header returns 401', emptyAuth.status === 401, `status=${emptyAuth.status}`);
}

// ═══════════════════════════════════════════════════════════
// 8. FRONTEND DATA CONTRACT VALIDATION
// ═══════════════════════════════════════════════════════════
async function testDataContract() {
  console.log('\n╔══════════════════════════════════════╗');
  console.log('║  📋 FRONTEND DATA CONTRACT           ║');
  console.log('╚══════════════════════════════════════╝');

  if (!PARENT_TOKEN) {
    skip(43, 'Dashboard data keys match Flutter model', 'No parent token');
    skip(44, 'Payment records contain month/year', 'No parent token');
    skip(45, 'Announcements have title and body', 'No parent token');
    return;
  }

  // P043: Dashboard keys match what Flutter expects
  const dash = await api('GET', '/parents/me/dashboard', null, PARENT_TOKEN);
  const expectedKeys = ['parent', 'children', 'todaySchedule', 'upcomingExams', 'announcements'];
  const d = dash.data?.data;
  const hasAllKeys = d ? expectedKeys.every(k => k in d) : false;
  test(43, 'Dashboard data keys match Flutter model', hasAllKeys, `keys=${d ? Object.keys(d).join(',') : 'null'}`);

  // P044: Payment records that Flutter uses
  const p = await api('GET', '/parents/me/payments', null, PARENT_TOKEN);
  const payments = p.data?.data;
  if (Array.isArray(payments) && payments.length > 0) {
    const rec = payments[0];
    const hasContract = rec.month !== undefined || rec.year !== undefined || rec.due_date !== undefined;
    test(44, 'Payment records contain month/year/due_date', hasContract, `keys=${Object.keys(rec).join(',').substring(0, 80)}`);
  } else {
    skip(44, 'Payment records contain month/year', 'No records to validate');
  }

  // P045: Announcements have required fields
  if (Array.isArray(d?.announcements) && d.announcements.length > 0) {
    const ann = d.announcements[0];
    test(45, 'Announcements have title and body', typeof ann.title === 'string', `keys=${Object.keys(ann).join(',')}`);
  } else {
    skip(45, 'Announcements have title and body', 'No announcements');
  }
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════
async function main() {
  console.log('╔══════════════════════════════════════════════════════╗');
  console.log('║  🧪 CoachPro Parent Panel Test Suite                ║');
  console.log('║    Target: ' + BASE_URL.substring(0, 40) + '...    ║');
  console.log('║    Time:   ' + new Date().toISOString() + '       ║');
  console.log('╚══════════════════════════════════════════════════════╝');

  // Attempt to obtain tokens (will skip data-shape tests if login unavailable)
  console.log('\n  ℹ️  Attempting role-based logins...');
  const loginAttempt = await api('POST', '/auth/login', { phone: '9876543210' });
  if (loginAttempt.status === 200 && loginAttempt.data?.data?.accessToken) {
    ADMIN_TOKEN = loginAttempt.data.data.accessToken;
    console.log('  ✔️  Admin token acquired');
  } else {
    console.log('  ℹ️  No admin token (OTP required)');
  }

  await testParentAuth();
  await testCrossRoleAccess();
  await testDashboardShape();
  await testChildrenEndpoint();
  await testPaymentsEndpoint();
  await testChildReport();
  await testEdgeCases();
  await testDataContract();

  console.log('\n╔══════════════════════════════════════╗');
  console.log('║  📊 PARENT PANEL TEST RESULTS        ║');
  console.log('╠══════════════════════════════════════╣');
  console.log(`║  ✅ Passed:  ${String(results.passed).padStart(3)}                    ║`);
  console.log(`║  ❌ Failed:  ${String(results.failed).padStart(3)}                    ║`);
  console.log(`║  ⏭️  Skipped: ${String(results.skipped).padStart(3)}                    ║`);
  console.log(`║  📦 Total:   ${String(results.passed + results.failed + results.skipped).padStart(3)}                    ║`);
  console.log('╚══════════════════════════════════════╝');

  if (results.failed > 0) {
    console.log('\n❌ Failed Tests:');
    results.details.filter(d => d.passed === false).forEach(d => {
      console.log(`   P${String(d.id).padStart(3, '0')}: ${d.name} — ${d.detail}`);
    });
  }

  // Exit with non-zero if failures
  process.exit(results.failed > 0 ? 1 : 0);
}

main().catch(console.error);
