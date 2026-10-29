import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ejercicios_app/core/data/firestore_errors.dart';
import 'package:ejercicios_app/core/data/firestore_mappers.dart';
import 'package:ejercicios_app/core/domain/member.dart';
import 'package:ejercicios_app/core/domain/repositories.dart';
import 'package:ejercicios_app/core/result.dart';

class FirestoreMemberRepository implements MemberRepository {
  new(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<Account?> watchAccount(String authUid) =>
      _db.collection('accounts').doc(authUid).snapshots().map((d) {
        final data = d.data();
        return data == null ? null : accountFromFirestore(data);
      });

  @override
  Stream<Member?> watchMember(String memberId) =>
      _db.collection('members').doc(memberId).snapshots().map((d) {
        final data = d.data();
        return data == null ? null : memberFromFirestore(d.id, data);
      });

  @override
  Future<Result<void>> updateLastPlaylist(String memberId, String playlistId) =>
      guardFirestore(
        () => _db.collection('members').doc(memberId).update({
          'last_playlist_id': playlistId,
          'updated_at': FieldValue.serverTimestamp(),
        }),
      );
}
