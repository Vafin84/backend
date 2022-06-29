import 'dart:io';

import 'package:auth/models/user.dart';
import 'package:auth/utils/app_const.dart';
import 'package:auth/utils/app_response.dart';
import 'package:auth/utils/app_utils.dart';
import 'package:conduit/conduit.dart';

class AppUserController extends ResourceController {
  final ManagedContext managedContext;

  AppUserController(this.managedContext);

  @Operation.get()
  Future<Response> getProfile(@Bind.header(HttpHeaders.authorizationHeader) String header) async {
    try {
      final id = AppUtils.getIdFromHeader(header);
      final user = await managedContext.fetchObjectWithID<User>(id);
      user?.removePropertiesFromBackingMap([AppConst.accessToken, AppConst.refreshToken]);
      return AppResponse.ok(body: user?.backing.contents, message: "Успешное получение профиля");
    } catch (error) {
      return AppResponse.serverError(error, message: "Ошибка получения профиля");
    }
  }

  @Operation.post()
  Future<Response> updateProfile(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.body() User user,
  ) async {
    try {
      final id = AppUtils.getIdFromHeader(header);
      final fUser = await managedContext.fetchObjectWithID<User>(id);
      final qUpdateUser = Query<User>(managedContext)
        ..where((x) => x.id).equalTo(id)
        ..values.username = user.username ?? fUser?.username
        ..values.email = user.email ?? fUser?.email;
      await qUpdateUser.updateOne();
      final uUser = await managedContext.fetchObjectWithID<User>(id);
      uUser?.removePropertiesFromBackingMap([AppConst.accessToken, AppConst.refreshToken]);
      return AppResponse.ok(body: uUser?.backing.contents, message: "Успешное обновление данных пользователя");
    } catch (error) {
      return AppResponse.serverError(error, message: "Ошибка обновления данных пользователя");
    }
  }

  @Operation.put()
  Future<Response> updatePassword(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.query("oldPassword") String oldPassword,
    @Bind.query("newPassword") String newPassword,
  ) async {
    try {
      final id = AppUtils.getIdFromHeader(header);
      final qFindUser = Query<User>(managedContext)
        ..where((table) => table.id).equalTo(id)
        ..returningProperties((table) => [table.salt, table.hashPassword]);
      final findUser = await qFindUser.fetchOne();
      final salt = findUser?.salt ?? "";
      final oldPasswordHash = AuthUtility.generatePasswordHash(oldPassword, salt);
      if (oldPasswordHash != findUser?.hashPassword) {
        return AppResponse.badRequest(message: "пароль неверный");
      }
      final newPasswordHash = AuthUtility.generatePasswordHash(newPassword, salt);
      final qUpdateuser = Query<User>(managedContext)
        ..where((x) => x.id).equalTo(id)
        ..values.hashPassword = newPasswordHash;
      await qUpdateuser.updateOne();

      return AppResponse.ok(message: "Пароль успешно обновлен");
    } catch (error) {
      return AppResponse.serverError(error, message: "Ошибка обновления пароля");
    }
  }
}
