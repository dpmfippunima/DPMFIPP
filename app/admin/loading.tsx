export default function AdminLoading() {
  return (
    <div className="adminLoading">
      <div className="adminLoadingSpinner" />

      <p>
        Memuat data...
      </p>
    </div>
  );
}

<div className="dashboardGrid">
  {Array.from({ length: 4 }).map((_, index) => (
    <div
      key={index}
      className="skeletonCard"
    >
      <div className="skeleton skeletonText" />

      <div className="skeleton skeletonTitle" />

      <div className="skeleton skeletonText" />
    </div>
  ))}
</div>