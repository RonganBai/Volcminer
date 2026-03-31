import 'package:volcminer/domain/entities/tracked_miner.dart';

class AbnormalMinerGroup {
  static const String soft = 'soft';
  static const String unknown = 'unknown';
  static const String hard = 'hard';
  static const String reboot = 'reboot';
}

class AbnormalMinerType {
  static const String zeroHash = 'zero_hash';
  static const String reauth = 'reauth';
  static const String multiRestart = 'multi_restart';
  static const String temperature = 'temperature';
  static const String droppedBoard = 'dropped_board';
  static const String allBoardFailure = 'all_board_failure';
  static const String power = 'power';
  static const String fan = 'fan';
  static const String hashboard = 'hashboard';
  static const String generic = 'generic';
}

class AbnormalMinerUtils {
  AbnormalMinerUtils._();

  static bool isAbnormal(TrackedMiner miner) {
    return abnormalGroupOf(miner) != null;
  }

  static bool isSoftAbnormal(TrackedMiner miner) {
    return abnormalGroupOf(miner) == AbnormalMinerGroup.soft;
  }

  static bool isUnknownAbnormal(TrackedMiner miner) {
    return abnormalGroupOf(miner) == AbnormalMinerGroup.unknown;
  }

  static bool isHardAbnormal(TrackedMiner miner) {
    return abnormalGroupOf(miner) == AbnormalMinerGroup.hard;
  }

  static bool isSoftOrUnknownAbnormal(TrackedMiner miner) {
    final group = abnormalGroupOf(miner);
    return group == AbnormalMinerGroup.soft ||
        group == AbnormalMinerGroup.unknown;
  }

  static bool isMultiRestart(TrackedMiner miner) {
    return abnormalGroupOf(miner) == AbnormalMinerGroup.reboot ||
        miner.diagnosis?.code == 'MULTI_RESTART';
  }

  static bool isSelfCheckFailure(TrackedMiner miner) {
    final diagnosis = miner.diagnosis;
    return diagnosis != null &&
        diagnosis.secondaryCode != null &&
        isSoftOrUnknownAbnormal(miner);
  }

  static String? abnormalGroupOf(TrackedMiner miner) {
    final code = miner.diagnosis?.code;
    if (code != null) {
      switch (code) {
        case 'ZERO_HASH_RESTARTING':
        case 'AUTHEN_START_WAIT':
        case 'TEMP_FULL_SPEED_RECOVERING':
        case 'HASHBOARD_DROPPED_RESTARTING':
        case 'HASHBOARD_ALL_FAILED_RESTARTING':
          return AbnormalMinerGroup.soft;
        case 'MULTI_RESTART':
          return AbnormalMinerGroup.reboot;
        case 'ERRORMSG':
        case 'UNKNOWN_ZERO_HASH':
          return AbnormalMinerGroup.unknown;
        default:
          return AbnormalMinerGroup.hard;
      }
    }
    if (miner.state == TrackedMinerState.online &&
        miner.effectiveHashrate <= 0) {
      return AbnormalMinerGroup.soft;
    }
    return null;
  }

  static String? abnormalTypeOf(TrackedMiner miner) {
    final code = miner.diagnosis?.code;
    if (code != null) {
      switch (code) {
        case 'ZERO_HASH_RESTARTING':
        case 'ZERO_HASH_RESTART_FAILED':
          return AbnormalMinerType.zeroHash;
        case 'AUTHEN_START_WAIT':
          return AbnormalMinerType.reauth;
        case 'TEMP_FULL_SPEED_RECOVERING':
        case 'TEMP_FULL_SPEED_PERSISTED':
        case 'OVER_MAX_TEMP':
          return AbnormalMinerType.temperature;
        case 'HASHBOARD_DROPPED_RESTARTING':
        case 'HASHBOARD_DROPPED_RESTART_FAILED':
          return AbnormalMinerType.droppedBoard;
        case 'HASHBOARD_ALL_FAILED_RESTARTING':
        case 'HASHBOARD_ALL_FAILED_NEEDS_REPLACEMENT':
          return AbnormalMinerType.allBoardFailure;
        case 'MULTI_RESTART':
          return AbnormalMinerType.multiRestart;
        case 'POWER_SUPPLY_FAULT':
        case 'OVER_VOLTAGE':
        case 'POWER_CONTROL_FAULT':
          return AbnormalMinerType.power;
        case 'FAN_ERROR':
          return AbnormalMinerType.fan;
        case 'CHAIN_BREAK':
          return AbnormalMinerType.hashboard;
        default:
          return AbnormalMinerType.generic;
      }
    }
    if (miner.state == TrackedMinerState.online &&
        miner.effectiveHashrate <= 0) {
      return AbnormalMinerType.zeroHash;
    }
    return null;
  }
}
