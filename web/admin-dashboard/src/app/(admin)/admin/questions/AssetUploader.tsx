"use client";

import Image from "next/image";
import { useCallback, useEffect, useState } from "react";
import { getSupabaseClient } from "@/lib/supabaseClient";
import {
  createQuestionAsset,
  deleteQuestionAsset,
  listQuestionAssets,
  type QuestionAsset,
} from "./actions";

type AssetUploaderProps = {
  questionId: string;
};

export function AssetUploader({ questionId }: AssetUploaderProps) {
  const supabase = getSupabaseClient();
  const [assets, setAssets] = useState<QuestionAsset[]>([]);
  const [loading, setLoading] = useState(true);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadAssets = useCallback(async () => {
    if (!supabase) return;
    const { data: sessionData } = await supabase.auth.getSession();
    const session = sessionData.session;
    if (!session) return;

    try {
      const data = await listQuestionAssets(session.access_token, questionId);
      setAssets(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load assets.");
    } finally {
      setLoading(false);
    }
  }, [supabase, questionId]);

  useEffect(() => {
    loadAssets();
  }, [loadAssets]);

  async function handleUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file || !supabase) return;

    const { data: sessionData } = await supabase.auth.getSession();
    const session = sessionData.session;
    if (!session) {
      setError("You are not signed in.");
      return;
    }

    setUploading(true);
    setError(null);

    try {
      const signResponse = await fetch(
        `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/sign-asset-upload`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${session.access_token}`,
          },
          body: JSON.stringify({
            question_id: questionId,
            file_name: file.name,
            content_type: file.type,
          }),
        },
      );

      if (!signResponse.ok) {
        const err = await signResponse.json();
        throw new Error(err.error || "Failed to get upload URL.");
      }

      const { signed_url, storage_path, public_url } = await signResponse.json();

      const uploadResponse = await fetch(signed_url, {
        method: "PUT",
        headers: { "Content-Type": file.type },
        body: file,
      });

      if (!uploadResponse.ok) {
        throw new Error("Failed to upload file.");
      }

      const asset = await createQuestionAsset(
        session.access_token,
        questionId,
        public_url,
        file.type,
        storage_path,
      );

      setAssets((prev) => [...prev, asset]);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Upload failed.");
    } finally {
      setUploading(false);
      e.target.value = "";
    }
  }

  async function handleDelete(assetId: string) {
    if (!supabase) return;
    const confirmed = window.confirm("Delete this asset?");
    if (!confirmed) return;

    const { data: sessionData } = await supabase.auth.getSession();
    const session = sessionData.session;
    if (!session) return;

    try {
      await deleteQuestionAsset(session.access_token, assetId);
      setAssets((prev) => prev.filter((a) => a.id !== assetId));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to delete asset.");
    }
  }

  if (loading) {
    return <p className="text-sm text-zinc-500">Loading assets...</p>;
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <span className="text-sm font-medium text-zinc-700">Images & Assets</span>
        <label className="cursor-pointer rounded-lg border border-zinc-200 px-3 py-1 text-xs text-zinc-700 hover:border-zinc-300">
          {uploading ? "Uploading..." : "+ Add Image"}
          <input
            type="file"
            accept="image/*"
            onChange={handleUpload}
            disabled={uploading}
            className="hidden"
          />
        </label>
      </div>

      {error && (
        <p className="text-xs text-red-600">{error}</p>
      )}

      {assets.length === 0 ? (
        <p className="text-sm text-zinc-500">No assets uploaded yet.</p>
      ) : (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4">
          {assets.map((asset) => (
            <div
              key={asset.id}
              className="group relative overflow-hidden rounded-lg border border-zinc-200 bg-zinc-50"
            >
              <Image
                src={asset.asset_url}
                alt="Question asset"
                className="h-24 w-full object-cover"
                width={192}
                height={96}
              />
              <button
                type="button"
                onClick={() => handleDelete(asset.id)}
                className="absolute right-1 top-1 rounded-full bg-red-500 p-1 text-white opacity-0 transition group-hover:opacity-100"
                title="Delete"
                aria-label="Delete asset"
              >
                <svg className="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
