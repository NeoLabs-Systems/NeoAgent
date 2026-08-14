'use strict';

const os = require('os');

const MIB = 1024 * 1024;
const GIB = 1024 * MIB;

function integerSetting(value, fallback, minimum, maximum) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(maximum, Math.max(minimum, Math.round(parsed)));
}

function getComputerResourceProfile(options = {}) {
  const totalMemoryMb = Math.floor(Number(options.totalMemoryBytes ?? os.totalmem()) / MIB);
  const logicalCpuCount = Math.max(1, Number(options.logicalCpuCount ?? os.cpus().length));
  const preferredAccelerator = String(options.accelerator || '').trim().toLowerCase();

  const reservePercent = integerSetting(
    options.reservePercent ?? process.env.NEOAGENT_COMPUTER_HOST_MEMORY_RESERVE_PERCENT,
    25,
    10,
    75,
  );
  const minimumReserveMb = integerSetting(
    options.minimumReserveMb ?? process.env.NEOAGENT_COMPUTER_HOST_MEMORY_RESERVE_MB,
    2048,
    512,
    131072,
  );
  const minimumGuestMemoryMb = integerSetting(
    options.minimumGuestMemoryMb ?? process.env.NEOAGENT_COMPUTER_MIN_MEMORY_MB,
    1536,
    1024,
    32768,
  );
  const maximumGuestMemoryMb = integerSetting(
    options.maximumGuestMemoryMb ?? process.env.NEOAGENT_COMPUTER_MAX_MEMORY_MB,
    2560,
    minimumGuestMemoryMb,
    65536,
  );
  const maximumGuestCpus = integerSetting(
    options.maximumGuestCpus ?? process.env.NEOAGENT_COMPUTER_MAX_CPUS,
    2,
    1,
    32,
  );
  const minimumDiskGiB = integerSetting(
    options.minimumDiskGiB ?? process.env.NEOAGENT_COMPUTER_MIN_DISK_GIB,
    6,
    4,
    1024,
  );
  const maximumDiskGiB = integerSetting(
    options.maximumDiskGiB ?? process.env.NEOAGENT_COMPUTER_MAX_DISK_GIB,
    12,
    minimumDiskGiB,
    4096,
  );

  const reserveMemoryMb = Math.max(
    minimumReserveMb,
    Math.ceil(totalMemoryMb * reservePercent / 100),
  );
  const allocatableMemoryMb = Math.max(0, totalMemoryMb - reserveMemoryMb);
  const allocatableCpuCount = Math.max(0, logicalCpuCount - 1);
  let maxActiveComputers = Math.max(
    0,
    Math.min(
      Math.floor(allocatableMemoryMb / minimumGuestMemoryMb),
      allocatableCpuCount,
    ),
  );
  if (preferredAccelerator === 'tcg') {
    maxActiveComputers = Math.min(maxActiveComputers, 1);
  }

  return Object.freeze({
    totalMemoryMb,
    logicalCpuCount,
    reservePercent,
    minimumReserveMb,
    reserveMemoryMb,
    allocatableMemoryMb,
    allocatableCpuCount,
    minimumGuestMemoryMb,
    maximumGuestMemoryMb,
    maximumGuestCpus,
    minimumDiskGiB,
    maximumDiskGiB,
    maxActiveComputers,
    storageReservePercent: integerSetting(
      options.storageReservePercent ?? process.env.NEOAGENT_COMPUTER_STORAGE_RESERVE_PERCENT,
      20,
      0,
      80,
    ),
  });
}

function allocateComputerResources(profile, activeAllocations = []) {
  const usedMemoryMb = activeAllocations.reduce(
    (total, allocation) => total + Math.max(0, Number(allocation?.memoryMb || 0)),
    0,
  );
  const usedCpuCount = activeAllocations.reduce(
    (total, allocation) => total + Math.max(0, Number(allocation?.cpus || 0)),
    0,
  );
  const remainingMemoryMb = profile.allocatableMemoryMb - usedMemoryMb;
  const remainingCpuCount = profile.allocatableCpuCount - usedCpuCount;
  if (
    activeAllocations.length >= profile.maxActiveComputers
    || remainingMemoryMb < profile.minimumGuestMemoryMb
    || remainingCpuCount < 1
  ) {
    const error = new Error('This host does not currently have capacity for another cloud computer.');
    error.code = 'COMPUTER_CAPACITY';
    error.status = 503;
    throw error;
  }

  const computersAfterAllocation = activeAllocations.length + 1;
  const guaranteedFutureComputers = Math.max(
    0,
    profile.maxActiveComputers - computersAfterAllocation,
  );
  const memoryReservedForFutureGuests = guaranteedFutureComputers
    * profile.minimumGuestMemoryMb;
  const cpusReservedForFutureGuests = guaranteedFutureComputers;

  return Object.freeze({
    memoryMb: Math.min(
      profile.maximumGuestMemoryMb,
      Math.max(profile.minimumGuestMemoryMb, remainingMemoryMb - memoryReservedForFutureGuests),
    ),
    cpus: Math.min(
      profile.maximumGuestCpus,
      Math.max(1, remainingCpuCount - cpusReservedForFutureGuests),
    ),
  });
}

function getStorageHeadroomBytes(profile, storage) {
  const input = typeof storage === 'object' && storage !== null
    ? storage
    : { availableBytes: storage };
  const availableBytes = Number(input.availableBytes || 0);
  if (!Number.isFinite(availableBytes) || availableBytes <= 0) return 0;
  const sparseLiabilityBytes = Math.max(0, Number(input.sparseLiabilityBytes || 0));
  const hostReserveBytes = availableBytes * profile.storageReservePercent / 100;
  return Math.floor(availableBytes - hostReserveBytes - sparseLiabilityBytes);
}

function chooseDataDiskGiB(profile, storage) {
  const availableGiB = Math.floor(getStorageHeadroomBytes(profile, storage) / GIB);
  if (!Number.isFinite(availableGiB) || availableGiB <= 0) {
    if (typeof storage !== 'object' || storage === null) return profile.minimumDiskGiB;
    const error = new Error('This host does not have enough free storage for another cloud computer disk.');
    error.code = 'COMPUTER_STORAGE_CAPACITY';
    error.status = 507;
    throw error;
  }
  if (availableGiB < profile.minimumDiskGiB) {
    const error = new Error('This host does not have enough free storage for another cloud computer disk.');
    error.code = 'COMPUTER_STORAGE_CAPACITY';
    error.status = 507;
    throw error;
  }
  return Math.min(
    profile.maximumDiskGiB,
    availableGiB,
  );
}

module.exports = {
  allocateComputerResources,
  chooseDataDiskGiB,
  getComputerResourceProfile,
  getStorageHeadroomBytes,
};
