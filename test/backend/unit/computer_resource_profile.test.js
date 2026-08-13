'use strict';

const assert = require('node:assert/strict');
const { test } = require('node:test');

const {
  allocateComputerResources,
  chooseDataDiskGiB,
  getComputerResourceProfile,
  getStorageHeadroomBytes,
} = require('../../../server/services/runtime/resource_profile');

test('computer profile preserves host RAM and CPU reserves', () => {
  const profile = getComputerResourceProfile({
    totalMemoryBytes: 16 * 1024 * 1024 * 1024,
    logicalCpuCount: 8,
    accelerator: 'kvm',
  });

  assert.equal(profile.reserveMemoryMb, 4096);
  assert.equal(profile.allocatableMemoryMb, 12288);
  assert.equal(profile.allocatableCpuCount, 7);
  assert.equal(profile.maxActiveComputers, 7);
});

test('allocations keep guaranteed capacity for every admitted computer', () => {
  const profile = getComputerResourceProfile({
    totalMemoryBytes: 8 * 1024 * 1024 * 1024,
    logicalCpuCount: 4,
  });
  const active = [];

  while (active.length < profile.maxActiveComputers) {
    active.push(allocateComputerResources(profile, active));
  }

  assert.ok(active.every((item) => item.memoryMb >= 1536 && item.cpus >= 1));
  assert.ok(active.reduce((sum, item) => sum + item.memoryMb, 0) <= profile.allocatableMemoryMb);
  assert.ok(active.reduce((sum, item) => sum + item.cpus, 0) <= profile.allocatableCpuCount);
  assert.throws(
    () => allocateComputerResources(profile, active),
    (error) => error.code === 'COMPUTER_CAPACITY',
  );
  assert.equal(chooseDataDiskGiB(profile, {
    availableBytes: 40 * 1024 ** 3,
    totalBytes: 100 * 1024 ** 3,
    sparseLiabilityBytes: 8 * 1024 ** 3,
  }), 12);
  assert.equal(
    getStorageHeadroomBytes(profile, {
      availableBytes: 40 * 1024 ** 3,
      totalBytes: 100 * 1024 ** 3,
      sparseLiabilityBytes: 8 * 1024 ** 3,
    }),
    24 * 1024 ** 3,
  );
});

test('storage reserve remains usable when the host is already below 20 percent free', () => {
  const profile = getComputerResourceProfile({ storageReservePercent: 20 });
  const storage = {
    availableBytes: 28 * 1024 ** 3,
    totalBytes: 228 * 1024 ** 3,
    sparseLiabilityBytes: 8 * 1024 ** 3,
  };

  assert.equal(chooseDataDiskGiB(profile, storage), 12);
  assert.ok(getStorageHeadroomBytes(profile, storage) >= 14 * 1024 ** 3);
});

test('TCG compatibility mode and sparse disk sizing remain bounded', () => {
  const profile = getComputerResourceProfile({
    totalMemoryBytes: 32 * 1024 * 1024 * 1024,
    logicalCpuCount: 16,
    accelerator: 'tcg',
  });
  assert.equal(profile.maxActiveComputers, 1);
  assert.equal(chooseDataDiskGiB(profile, 100 * 1024 ** 3), 12);
  assert.equal(chooseDataDiskGiB(profile, 8 * 1024 ** 3), 6);
  assert.throws(
    () => chooseDataDiskGiB(profile, 7 * 1024 ** 3),
    (error) => error.code === 'COMPUTER_STORAGE_CAPACITY',
  );
});

test('an explicit administrator override may lower the storage reserve to zero', () => {
  const profile = getComputerResourceProfile({ storageReservePercent: 0 });
  assert.equal(profile.storageReservePercent, 0);
});
