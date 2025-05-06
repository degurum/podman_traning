# ベースとなるイメージを指定 (Gradle & Java 17)
FROM public.ecr.aws/docker/library/gradle:jdk17 AS build

# 作業ディレクトリを設定
WORKDIR /app

# Gradle Wrapperとビルド設定ファイルをコピー
# demo/ ディレクトリからコピーするようにパスを修正
COPY demo/gradlew ./gradlew
COPY demo/gradlew.bat ./gradlew.bat
COPY demo/gradle ./gradle
COPY demo/build.gradle ./build.gradle
COPY demo/settings.gradle ./settings.gradle

# Gradle Wrapperに実行権限を付与 (Linuxコンテナ用)
RUN chmod +x ./gradlew

# 依存関係をダウンロード (キャッシュ効率化のため、先に実行することも可能ですが、ビルド時に解決されるため省略)
# RUN ./gradlew dependencies --no-daemon

# アプリケーションのソースコードをコピー
# demo/ ディレクトリからコピーするようにパスを修正
COPY demo/src ./src

# Gradleでアプリケーションをビルド (jarファイルを作成)
# --no-daemon オプションはコンテナ環境での実行を安定させるために推奨
# bootJar タスクは Spring Boot アプリケーションの実行可能JARを生成
RUN ./gradlew bootJar --no-daemon -x test

# 実行用の軽量なJREイメージを指定
FROM public.ecr.aws/docker/library/openjdk:17-slim

# 作業ディレクトリを設定
WORKDIR /app

# Lambdaアダプターを使用する
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.9.1 /lambda-adapter /opt/extensions/lambda-adapter 
ENV AWS_LWA_PORT=8080
ENV AWS_LWA_READINESS_CHECK_PATH=/actuator/health

# ビルドステージから生成されたjarファイルをコピー
# Gradleの出力パス (build/libs) とファイル名を指定
# Spring BootのbootJarタスクで生成されるJARファイル名を想定
COPY --from=build /app/build/libs/*.jar app.jar

# コンテナ起動時に実行するコマンド
ENTRYPOINT ["java", "-jar", "app.jar"]

# (オプション) アプリケーションが使用するポートを公開 (Spring Bootのデフォルトは8080)
EXPOSE 8080
