const path = require('path');
const fs = require('fs');

async function updateRoutes(fastify) {
  const RELEASES_DIR = path.resolve(__dirname, '../../../releases');

  // 최신 버전 정보 조회
  fastify.get('/api/update/check', async (request, reply) => {
    const versionFile = path.join(RELEASES_DIR, 'version.json');
    if (!fs.existsSync(versionFile)) {
      return reply.status(404).send({ error: '버전 정보가 없습니다.' });
    }
    const info = JSON.parse(fs.readFileSync(versionFile, 'utf-8').replace(/^\uFEFF/, ''));
    return info;
  });

  // APK 다운로드
  fastify.get('/api/update/download', async (request, reply) => {
    const versionFile = path.join(RELEASES_DIR, 'version.json');
    if (!fs.existsSync(versionFile)) {
      return reply.status(404).send({ error: '배포 파일이 없습니다.' });
    }
    const info = JSON.parse(fs.readFileSync(versionFile, 'utf-8').replace(/^\uFEFF/, ''));
    const apkPath = path.join(RELEASES_DIR, info.apkFile);

    if (!fs.existsSync(apkPath)) {
      return reply.status(404).send({ error: 'APK 파일을 찾을 수 없습니다.' });
    }

    const stream = fs.createReadStream(apkPath);
    return reply
      .type('application/vnd.android.package-archive')
      .header('Content-Disposition', `attachment; filename="${info.apkFile}"`)
      .send(stream);
  });
}

module.exports = updateRoutes;
