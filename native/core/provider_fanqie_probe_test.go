package core

// 番茄站源的实机联调测试：需要本机 127.0.0.1:18999 有一个跑起来的 fqapi
// 核心（fqapp/rust 的 probe 二进制）。设 FANQIE_PROBE=1 才会执行，
// 普通go test / CI 不受影响。

import (
	"context"
	"net/http"
	"os"
	"testing"
	"time"
)

func fanqieProbeDownloader(t *testing.T) *Downloader {
	t.Helper()
	if os.Getenv("FANQIE_PROBE") != "1" {
		t.Skip("需要 FANQIE_PROBE=1 与本机番茄核心（127.0.0.1:18999）")
	}
	cfg := defaultConfig()
	cfg.FanqieURL = "http://127.0.0.1:18999" // probe 端口；线上走 18921
	return &Downloader{
		cfg:     cfg,
		client:  &http.Client{Timeout: 30 * time.Second},
		limiter: newRequestLimiter(3, 0),
	}
}

func TestFanqieProbeCatalog(t *testing.T) {
	d := fanqieProbeDownloader(t)
	ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
	defer cancel()
	items, hasMore, err := d.fetchFanqieCatalogPage(ctx, fanqieCategoryKanju, 1)
	if err != nil {
		t.Fatalf("目录第一页失败: %v", err)
	}
	if len(items) == 0 {
		t.Fatal("目录第一页为空")
	}
	t.Logf("看剧目录 %d 部, hasMore=%v, 第一部: %s (%s) 封面=%s",
		len(items), hasMore, items[0].DisplayTitle(), items[0].ID, items[0].Cover)
	if items[0].Source != sourceFanqie || items[0].SourceID == "" {
		t.Fatalf("站源字段无效: %+v", items[0])
	}
}

func TestFanqieProbeSearch(t *testing.T) {
	d := fanqieProbeDownloader(t)
	ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
	defer cancel()
	items, hasMore, err := d.fetchFanqieSearchPage(ctx, 1, "逆袭")
	if err != nil {
		t.Fatalf("搜索失败: %v", err)
	}
	if len(items) == 0 {
		t.Fatal("搜索结果为空")
	}
	t.Logf("搜索 %d 条, hasMore=%v, 第一条: %s (%s)", len(items), hasMore, items[0].DisplayTitle(), items[0].ID)
}

func TestFanqieProbeDetailAndPlayback(t *testing.T) {
	d := fanqieProbeDownloader(t)
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	_, chapters, err := d.fetchFanqieDetail(ctx, "7685227828454886424")
	if err != nil {
		t.Fatalf("详情失败: %v", err)
	}
	if len(chapters) == 0 {
		t.Fatal("详情没有分集")
	}
	t.Logf("分集 %d 集, 第一集: %s (id=%s)", len(chapters), chapters[0].Title, chapters[0].ID)
	media, err := d.resolveFanqieMedia(ctx, chapters[0])
	if err != nil {
		t.Fatalf("播放解析失败: %v", err)
	}
	if media.URL == "" {
		t.Fatal("播放地址为空")
	}
	t.Logf("播放地址: %s", media.URL)
}
