import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ejercicios_app/core/data/firestore_errors.dart';
import 'package:ejercicios_app/core/data/firestore_mappers.dart';
import 'package:ejercicios_app/core/domain/member.dart';
import 'package:ejercicios_app/core/domain/repositories.dart';
import 'package:ejercicios_app/core/result.dart';

/// Integrantes (members/), sus cuentas (accounts/) y TVs (tv_sessions/).
class FirestoreMemberAdminRepository implements MemberAdminRepository {
  new(this._db, this._creator);

  final FirebaseFirestore _db;
  final AccountCreator _creator;

  CollectionReference<Json> get _members => _db.collection('members');
  CollectionReference<Json> get _accounts => _db.collection('accounts');
  CollectionReference<Json> get _tvSessions => _db.collection('tv_sessions');

  @override
  Stream<List<Member>> watchMembers() => _members
      .orderBy('order')
      .snapshots()
      .map(
        (s) => [for (final d in s.docs) memberFromFirestore(d.id, d.data())],
      );

  @override
  Future<Result<Member>> createMember({
    required String displayName,
    required String username,
    required String password,
    required String colorHex,
    required String avatar,
  }) => guardFirestore(() async {
    final user = username.trim().toLowerCase();
    final taken = await _members
        .where('username', isEqualTo: user)
        .limit(1)
        .get();
    if (taken.docs.isNotEmpty) {
      throw const FailureException(AlreadyExistsFailure());
    }

    var order = 1;
    for (final d in (await _members.get()).docs) {
      final o = d.data()['order'];
      if (o is num && o >= order) order = o.toInt() + 1;
    }

    final uid = await _creator.createAccount(user, password);
    final ref = _members.doc();
    final now = FieldValue.serverTimestamp();
    await (_db.batch()
          ..set(ref, {
            'display_name': displayName.trim(),
            'username': user,
            'color_hex': colorHex,
            'avatar': avatar,
            'order': order,
            'is_active': true,
            'auth_uid': uid,
            'created_at': now,
            'updated_at': now,
          })
          ..set(_accounts.doc(uid), {
            'member_id': ref.id,
            'username': user,
            'is_active': true,
          }))
        .commit();

    return Member(
      id: ref.id,
      displayName: displayName.trim(),
      username: user,
      colorHex: colorHex,
      avatar: avatar,
      order: order,
      authUid: uid,
    );
  });

  @override
  Future<Result<void>> updateMember(Member member) => guardFirestore(
    () => _members.doc(member.id).update({
      'display_name': member.displayName.trim(),
      'color_hex': member.colorHex,
      'avatar': member.avatar,
      'updated_at': FieldValue.serverTimestamp(),
    }),
  );

  @override
  Future<Result<void>> setMemberActive(Member member, {required bool active}) =>
      guardFirestore(() async {
        final batch = _db.batch()
          ..update(_members.doc(member.id), {
            'is_active': active,
            'updated_at': FieldValue.serverTimestamp(),
          });
        final uid = member.authUid;
        if (uid != null) {
          batch.set(_accounts.doc(uid), {
            'member_id': member.id,
            'username': member.username,
            'is_active': active,
          });
        }
        if (!active) {
          final tvs = await _tvSessions
              .where('member_id', isEqualTo: member.id)
              .get();
          for (final tv in tvs.docs) {
            batch.delete(tv.reference);
          }
        }
        await batch.commit();
      });

  @override
  Future<Result<void>> restoreAccess(
    Member member, {
    required String newPassword,
  }) => guardFirestore(() async {
    final uid = await _creator.createAccount(member.username, newPassword);
    final batch = _db.batch()
      ..set(_accounts.doc(uid), {
        'member_id': member.id,
        'username': member.username,
        'is_active': member.isActive,
      })
      ..update(_members.doc(member.id), {
        'auth_uid': uid,
        'updated_at': FieldValue.serverTimestamp(),
      });
    final old = member.authUid;
    if (old != null && old != uid) batch.delete(_accounts.doc(old));
    await batch.commit();
  });

  @override
  Stream<List<TvSession>> watchTvSessions() => _tvSessions.snapshots().map(
    (s) => [for (final d in s.docs) tvSessionFromFirestore(d.id, d.data())],
  );

  @override
  Future<Result<void>> unlinkTv(String tvUid) =>
      guardFirestore(() => _tvSessions.doc(tvUid).delete());
}
