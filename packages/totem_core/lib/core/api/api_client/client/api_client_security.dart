// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:degenerate_runtime/degenerate_runtime.dart';

final class ClientSecurity {
  const ClientSecurity._();

  static final securitySchemes = <String, ApiSecurityScheme>{
    'JWTAuth': const ApiSecurityScheme(
      name: 'JWTAuth',
      type: ApiSecuritySchemeType.http,
      scheme: 'bearer',
    ),
    'SessionAuth': const ApiSecurityScheme(
      name: 'SessionAuth',
      type: ApiSecuritySchemeType.apiKey,
      parameterName: 'sessionid',
      location: ApiKeyLocation.cookie,
    ),
  };

  static final totemApiMobileApiRegisterFcmTokenRequirements =
      <ApiSecurityRequirement>[
        const ApiSecurityRequirement({'JWTAuth': []}),
        const ApiSecurityRequirement({'SessionAuth': []}),
      ];
  static final totemApiMobileApiUnregisterFcmTokenRequirements =
      <ApiSecurityRequirement>[
        const ApiSecurityRequirement({'JWTAuth': []}),
        const ApiSecurityRequirement({'SessionAuth': []}),
      ];
  static final totemOnboardMobileApiOnboardGetRequirements =
      <ApiSecurityRequirement>[
        const ApiSecurityRequirement({'JWTAuth': []}),
        const ApiSecurityRequirement({'SessionAuth': []}),
      ];
  static final totemOnboardMobileApiOnboardPostRequirements =
      <ApiSecurityRequirement>[
        const ApiSecurityRequirement({'JWTAuth': []}),
        const ApiSecurityRequirement({'SessionAuth': []}),
      ];
  static final totemUsersMobileApiGetCurrentUserRequirements =
      <ApiSecurityRequirement>[
        const ApiSecurityRequirement({'JWTAuth': []}),
        const ApiSecurityRequirement({'SessionAuth': []}),
      ];
  static final totemUsersMobileApiGetUserProfileRequirements =
      <ApiSecurityRequirement>[
        const ApiSecurityRequirement({'JWTAuth': []}),
        const ApiSecurityRequirement({'SessionAuth': []}),
      ];
  static final totemUsersMobileApiUpdateCurrentUserRequirements =
      <ApiSecurityRequirement>[
        const ApiSecurityRequirement({'JWTAuth': []}),
        const ApiSecurityRequirement({'SessionAuth': []}),
      ];
  static final totemUsersMobileApiUpdateCurrentUserImageRequirements =
      <ApiSecurityRequirement>[
        const ApiSecurityRequirement({'JWTAuth': []}),
        const ApiSecurityRequirement({'SessionAuth': []}),
      ];
  static final totemUsersMobileApiDeleteCurrentUserRequirements =
      <ApiSecurityRequirement>[
        const ApiSecurityRequirement({'JWTAuth': []}),
        const ApiSecurityRequirement({'SessionAuth': []}),
      ];
  static final totemUsersMobileApiKeeperRequirements = <ApiSecurityRequirement>[
    const ApiSecurityRequirement({'JWTAuth': []}),
    const ApiSecurityRequirement({'SessionAuth': []}),
  ];
  static final totemUsersMobileApiSubmitFeedbackRequirements =
      <ApiSecurityRequirement>[
        const ApiSecurityRequirement({'JWTAuth': []}),
        const ApiSecurityRequirement({'SessionAuth': []}),
      ];
  static final totemSpacesMobileApiSubscribeToSpaceRequirements =
      <ApiSecurityRequirement>[
        const ApiSecurityRequirement({'JWTAuth': []}),
        const ApiSecurityRequirement({'SessionAuth': []}),
      ];
  static final totemSpacesMobileApiUnsubscribeToSpaceRequirements =
      <ApiSecurityRequirement>[
        const ApiSecurityRequirement({'JWTAuth': []}),
        const ApiSecurityRequirement({'SessionAuth': []}),
      ];
  static final totemSpacesMobileApiListSubscriptionsRequirements =
      <ApiSecurityRequirement>[
        const ApiSecurityRequirement({'JWTAuth': []}),
        const ApiSecurityRequirement({'SessionAuth': []}),
      ];
  static final totemSpacesMobileApiListSpacesRequirements =
      <ApiSecurityRequirement>[
        const ApiSecurityRequirement({'JWTAuth': []}),
        const ApiSecurityRequirement({'SessionAuth': []}),
      ];
  static final totemSpacesMobileApiGetSpaceDetailRequirements =
      <ApiSecurityRequirement>[
        const ApiSecurityRequirement({'JWTAuth': []}),
        const ApiSecurityRequirement({'SessionAuth': []}),
      ];
  static final totemSpacesMobileApiGetKeeperSpacesRequirements =
      <ApiSecurityRequirement>[
        const ApiSecurityRequirement({'JWTAuth': []}),
        const ApiSecurityRequirement({'SessionAuth': []}),
      ];
  static final totemSpacesMobileApiGetSessionDetailRequirements =
      <ApiSecurityRequirement>[
        const ApiSecurityRequirement({'JWTAuth': []}),
        const ApiSecurityRequirement({'SessionAuth': []}),
      ];
  static final totemSpacesMobileApiPostSessionFeedbackRequirements =
      <ApiSecurityRequirement>[
        const ApiSecurityRequirement({'JWTAuth': []}),
        const ApiSecurityRequirement({'SessionAuth': []}),
      ];
  static final totemSpacesMobileApiGetSessionsHistoryRequirements =
      <ApiSecurityRequirement>[
        const ApiSecurityRequirement({'JWTAuth': []}),
        const ApiSecurityRequirement({'SessionAuth': []}),
      ];
  static final totemSpacesMobileApiGetRecommendedSpacesRequirements =
      <ApiSecurityRequirement>[
        const ApiSecurityRequirement({'JWTAuth': []}),
        const ApiSecurityRequirement({'SessionAuth': []}),
      ];
  static final totemSpacesMobileApiGetSpacesSummaryRequirements =
      <ApiSecurityRequirement>[
        const ApiSecurityRequirement({'JWTAuth': []}),
        const ApiSecurityRequirement({'SessionAuth': []}),
      ];
  static final totemSpacesMobileApiRsvpConfirmRequirements =
      <ApiSecurityRequirement>[
        const ApiSecurityRequirement({'JWTAuth': []}),
        const ApiSecurityRequirement({'SessionAuth': []}),
      ];
  static final totemSpacesMobileApiRsvpCancelRequirements =
      <ApiSecurityRequirement>[
        const ApiSecurityRequirement({'JWTAuth': []}),
        const ApiSecurityRequirement({'SessionAuth': []}),
      ];
  static final totemBlogMobileApiListPostsRequirements =
      <ApiSecurityRequirement>[
        const ApiSecurityRequirement({'JWTAuth': []}),
        const ApiSecurityRequirement({'SessionAuth': []}),
      ];
  static final totemBlogMobileApiPostRequirements = <ApiSecurityRequirement>[
    const ApiSecurityRequirement({'JWTAuth': []}),
    const ApiSecurityRequirement({'SessionAuth': []}),
  ];
  static final totemRoomsApiPostEventRequirements = <ApiSecurityRequirement>[
    const ApiSecurityRequirement({'JWTAuth': []}),
    const ApiSecurityRequirement({'SessionAuth': []}),
  ];
  static final totemRoomsApiGetStateRequirements = <ApiSecurityRequirement>[
    const ApiSecurityRequirement({'JWTAuth': []}),
    const ApiSecurityRequirement({'SessionAuth': []}),
  ];
  static final totemRoomsApiJoinRoomRequirements = <ApiSecurityRequirement>[
    const ApiSecurityRequirement({'JWTAuth': []}),
    const ApiSecurityRequirement({'SessionAuth': []}),
  ];
  static final totemRoomsApiMuteRequirements = <ApiSecurityRequirement>[
    const ApiSecurityRequirement({'JWTAuth': []}),
    const ApiSecurityRequirement({'SessionAuth': []}),
  ];
  static final totemRoomsApiDisableCameraRequirements =
      <ApiSecurityRequirement>[
        const ApiSecurityRequirement({'JWTAuth': []}),
        const ApiSecurityRequirement({'SessionAuth': []}),
      ];
  static final totemRoomsApiMuteAllRequirements = <ApiSecurityRequirement>[
    const ApiSecurityRequirement({'JWTAuth': []}),
    const ApiSecurityRequirement({'SessionAuth': []}),
  ];
  static final totemRoomsApiRemoveRequirements = <ApiSecurityRequirement>[
    const ApiSecurityRequirement({'JWTAuth': []}),
    const ApiSecurityRequirement({'SessionAuth': []}),
  ];

  static ApiConfig applyJWTAuth(ApiConfig config, String token) =>
      config.copyWith(
        defaultHeaders: {
          ...config.defaultHeaders,
          'Authorization': 'Bearer $token',
        },
      );

  static ApiConfig applySessionAuth(ApiConfig config, String value) => config
      .copyWith(defaultCookies: {...config.defaultCookies, 'sessionid': value});
}
