// TODO(backend): Remove this file once real API endpoints are available.
// All data here is stub data used until the backend ships the messaging APIs.

import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/messages/models/conversation.dart';

/// Person row shown in [NewMessageScreen] (keeper or participant).
typedef MockPerson = ({String id, String name, String seed, String? subtitle});

const mockKeepers = <MockPerson>[
  (id: 'conv_1', name: 'Vanessa', seed: 'vanessa-seed', subtitle: null),
  (id: 'conv_2', name: 'Marcus', seed: 'marcus-seed', subtitle: null),
  (id: 'conv_3', name: 'Sarah', seed: 'sarah-seed', subtitle: null),
  (id: 'conv_4', name: 'Jordan', seed: 'jordan-seed', subtitle: null),
  (id: 'conv_5', name: 'Alex', seed: 'alex-seed', subtitle: null),
];

const mockRecentParticipants = <MockPerson>[
  (
    id: 'conv_emily',
    name: 'Emily',
    seed: 'emily-seed',
    subtitle: 'Anxiety & Coping · Mar 30',
  ),
  (
    id: 'conv_rafael',
    name: 'Rafael',
    seed: 'rafael-seed',
    subtitle: 'Recovery Circle · Mar 28',
  ),
  (
    id: 'conv_tanya',
    name: 'Tanya',
    seed: 'tanya-seed',
    subtitle: 'Grief Support · Mar 27',
  ),
];

const mockOtherParticipants = <MockPerson>[
  (
    id: 'conv_derek',
    name: 'Derek',
    seed: 'derek-seed',
    subtitle: 'Anxiety & Coping · Mar 24',
  ),
  (
    id: 'conv_leila',
    name: 'Leila',
    seed: 'leila-seed',
    subtitle: 'Recovery Circle · Mar 21',
  ),
];

/// Detailed participant records used by [SessionParticipantsScreen] and
/// [ComposeToParticipantsScreen].
///
/// `id` is the thread/peer slug [conversationFromMockParticipant] uses, so it
/// must stay aligned with `name` — tapping "Kai" should open `conv_kai`, not
/// a leftover id from another person.
// TODO(backend): replace with real provider fetching session participants.
typedef MockParticipant = ({
  String id,
  String name,
  String email,
  String joinedSessions,
  int sessions,
  int reviews,
});

const mockSessionParticipants = <MockParticipant>[
  (
    id: 'conv_emily',
    name: 'Emily',
    email: 'emily@gmail.com',
    joinedSessions: 'Joined Mar 12 · 8 sessions',
    sessions: 8,
    reviews: 2,
  ),
  (
    id: 'conv_rafael',
    name: 'Rafael',
    email: 'rafael@gmail.com',
    joinedSessions: 'Joined Mar 5 · 12 sessions',
    sessions: 12,
    reviews: 4,
  ),
  (
    id: 'conv_tanya',
    name: 'Tanya',
    email: 'tanya@gmail.com',
    joinedSessions: 'Joined Feb 22 · 15 sessions',
    sessions: 15,
    reviews: 3,
  ),
  (
    id: 'conv_derek',
    name: 'Derek',
    email: 'derek@gmail.com',
    joinedSessions: 'Joined Mar 20 · 6 sessions',
    sessions: 6,
    reviews: 1,
  ),
  (
    id: 'conv_leila',
    name: 'Leila',
    email: 'leila@gmail.com',
    joinedSessions: 'Joined Mar 8 · 9 sessions',
    sessions: 9,
    reviews: 2,
  ),
  (
    id: 'conv_kai',
    name: 'Kai',
    email: 'kai@gmail.com',
    joinedSessions: 'Joined Mar 18 · 5 sessions',
    sessions: 5,
    reviews: 1,
  ),
  (
    id: 'conv_nina',
    name: 'Nina',
    email: 'nina@gmail.com',
    joinedSessions: 'Joined Feb 14 · 20 sessions',
    sessions: 20,
    reviews: 6,
  ),
  (
    id: 'conv_omar',
    name: 'Omar',
    email: 'omar@gmail.com',
    joinedSessions: 'Joined Mar 1 · 11 sessions',
    sessions: 11,
    reviews: 3,
  ),
];

/// Recommended keepers shown in the empty-state of [MessagesScreen].
// TODO(backend): replace with a real provider (e.g. recommended-keepers endpoint).
typedef MockRecommendedKeeper = ({String name, String seed});

const mockRecommendedKeepers = <MockRecommendedKeeper>[
  (name: 'James Moreau', seed: 'james-moreau'),
  (name: 'Sofia Reyes', seed: 'sofia-reyes'),
  (name: 'Lena Fischer', seed: 'lena-fischer'),
  (name: 'Omar Khalil', seed: 'omar-khalil'),
  (name: 'Dr. Aisha Patel', seed: 'aisha-patel'),
];

/// Builds a stub [Conversation] for navigation when the user taps a [MockPerson].
Conversation conversationFromMockPerson(MockPerson person) => Conversation(
  id: person.id,
  peer: PublicUserSchema(
    profileAvatarType: ProfileAvatarTypeEnum.td,
    dateCreated: DateTime.now(),
    name: person.name,
    slug: person.id,
    profileAvatarSeed: person.seed,
  ),
  updatedAt: DateTime.now(),
);

/// Builds a stub [Conversation] for navigation when the user taps a [MockParticipant].
Conversation conversationFromMockParticipant(MockParticipant participant) =>
    Conversation(
      id: participant.id,
      peer: PublicUserSchema(
        profileAvatarType: ProfileAvatarTypeEnum.td,
        dateCreated: DateTime.now(),
        name: participant.name,
        slug: participant.id,
        profileAvatarSeed: '${participant.id}-seed',
      ),
      updatedAt: DateTime.now(),
    );
