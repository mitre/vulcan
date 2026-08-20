export function useAuthToken() {
  const meta = document.querySelector("meta[name='csrf-token']");
  const authenticityToken = meta ? meta.getAttribute("content") : null;

  return { authenticityToken };
}
