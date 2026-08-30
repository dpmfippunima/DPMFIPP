"use client";

import { useActionState } from "react";
import { useFormStatus } from "react-dom";
import { saveFollowUpNote } from "./actions";

type FollowUpFormProps = {
  aspirationId: string;
  defaultNote: string | null;
};

const initialState = {
  success: false,
  message: "",
};

function SubmitButton() {
  const { pending } = useFormStatus();

  return (
    <button
      type="submit"
      className="button"
      disabled={pending}
    >
      {pending ? "Menyimpan..." : "Simpan Catatan"}
    </button>
  );
}

export function FollowUpForm({
  aspirationId,
  defaultNote,
}: FollowUpFormProps) {
  const [state, formAction] = useActionState(
    saveFollowUpNote,
    initialState
  );

  return (
    <form action={formAction} className="form">
      <input
        type="hidden"
        name="id"
        value={aspirationId}
      />

      <label>
        Catatan tindak lanjut

        <textarea
          name="follow_up_note"
          defaultValue={defaultNote ?? ""}
          rows={6}
          placeholder="Tuliskan tindakan atau perkembangan penanganan aspirasi..."
        />
      </label>

      <SubmitButton />

      {state.message && (
        <div
          className={state.success ? "success" : "error"}
          role="status"
        >
          {state.message}
        </div>
      )}
    </form>
  );
}