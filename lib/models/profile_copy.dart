import '../utils/constants.dart';

/// The complete allowlist for copying Main. Credentials and device preferences
/// cannot match this table; new keys must be deliberately assigned to an option.
enum ProfileCopy { favourites, history, sports, visibility, home }

const profileCopyKeys = <ProfileCopy, Set<String>>{
  ProfileCopy.favourites: {
    AppConstants.keyFavorites,
    AppConstants.keyFavoriteSeries,
    AppConstants.keyFavoriteLiveOrder,
    AppConstants.keyFavoriteLiveSort,
    AppConstants.keyArchiveFavorites
  },
  ProfileCopy.history: {
    AppConstants.keyLastChannelId,
    AppConstants.keyArchiveHistory
  },
  ProfileCopy.sports: {
    AppConstants.keyGoalsAlert,
    AppConstants.keyGoalAlertDelay,
    AppConstants.keySportsLeagues,
    AppConstants.keySportsAddedLeagues,
    AppConstants.keySportsFavoriteLeague,
    AppConstants.keySportsFollowedTeams,
    AppConstants.keySportsChannelPicks,
    AppConstants.keySportsHideScores,
    AppConstants.keySportsMode,
    AppConstants.keySportsChannelLists,
    AppConstants.keySportsPreferredCountries,
    AppConstants.keySportsPreferredPlaylist,
    AppConstants.keySportsHideEmptyLeagues,
    AppConstants.keySportsShowOdds,
    AppConstants.keySportsCardSize,
    AppConstants.keySportsLayout,
  },
  ProfileCopy.visibility: {
    AppConstants.keyMyGroups,
    AppConstants.keyArchiveSourcePrefs
  },
  ProfileCopy.home: {
    AppConstants.keyHomeRows,
    AppConstants.keyHideProfiles,
    AppConstants.keyHomeMiniPlayer,
    AppConstants.keyGuideViewMode,
    AppConstants.keyGuideFullVideo,
    AppConstants.keyGuideTransparency,
    AppConstants.keyGuideExpanded,
    AppConstants.keyGuideCompact,
    AppConstants.keyCompactUi,
    AppConstants.keyUiSize,
  },
};
const profileCopyPrefixes = <ProfileCopy, Set<String>>{
  ProfileCopy.favourites: {'${AppConstants.keyFavoritedGroups}_'},
  ProfileCopy.history: {
    AppConstants.keyLastPositionPrefix,
    AppConstants.keyLastDurationPrefix
  },
  ProfileCopy.visibility: {
    '${AppConstants.keyHiddenGroups}_',
    '${AppConstants.keyHiddenChannels}_',
    '${AppConstants.keyHiddenPlaylistGroups}_',
    '${AppConstants.keyGroupOrder}_',
    '${AppConstants.keyChannelOrder}_'
  },
};
bool copyMainKey(String key, Set<ProfileCopy> options) =>
    !key.contains(AppConstants.viewerKeySuffix) &&
    options.any((option) =>
        (profileCopyKeys[option]?.contains(key) ?? false) ||
        (profileCopyPrefixes[option]?.any(key.startsWith) ?? false));
