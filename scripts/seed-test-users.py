"""
부하 테스트용 유저 시딩 스크립트
=================================
목적:
  locustfile.py 에서 사용하는 테스트 유저 50명을
  회원가입 API(POST /api/v1/users)를 통해 DB에 생성

사용법:
  # 클러스터 내부 (kubectl port-forward 활용)
  kubectl port-forward svc/spring-portfogram-server 8080:8080 -n portfogram &
  python scripts/seed-test-users.py --host http://localhost:8080

  # 이미 생성된 유저 무시하고 재실행
  python scripts/seed-test-users.py --host http://localhost:8080 --skip-existing
"""

import requests
import argparse
import sys

# locustfile.py 와 반드시 동일해야 함
PREFIX = "lb1772269001"
TEST_USERS = [
    {
        "nickname": f"{PREFIX}{i:02d}",
        "email": f"{PREFIX}{i:02d}@portfogram.com",
        "name": f"LoadTest {i:02d}",
        "password": "LoadTest9999"
    }
    for i in range(1, 51)
]

def seed_users(host: str, skip_existing: bool):
    success, skipped, failed = 0, 0, 0

    print(f"\n[시딩 시작] host={host}, 총 {len(TEST_USERS)}명\n")

    for user in TEST_USERS:
        try:
            res = requests.post(
                f"{host}/api/v1/users",
                json=user,
                headers={"Content-Type": "application/json"},
                timeout=10
            )

            if res.status_code in (200, 201):
                print(f"  OK 생성: {user['email']}")
                success += 1

            elif res.status_code in (400, 409) and skip_existing:
                print(f"  SKIP (이미 존재): {user['email']}")
                skipped += 1

            else:
                print(f"  FAIL: {user['email']} -> {res.status_code} {res.text[:100]}")
                failed += 1

        except requests.exceptions.RequestException as e:
            print(f"  ERROR: {user['email']} -> {e}")
            failed += 1

    print(f"\n[완료] 성공: {success}명 | 스킵: {skipped}명 | 실패: {failed}명")

    if failed > 0:
        print("\n실패한 유저가 있습니다. 로그를 확인하세요.")
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="부하 테스트용 유저 시딩")
    parser.add_argument("--host", required=True, help="API 서버 host (예: http://localhost:8080)")
    parser.add_argument("--skip-existing", action="store_true", help="이미 존재하는 유저 무시")
    args = parser.parse_args()

    seed_users(args.host, args.skip_existing)
