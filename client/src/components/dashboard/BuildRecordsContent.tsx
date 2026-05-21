import type { BuildRecord } from '../../types'
import BuildTable from './BuildTable'
import BuildsErrorState from './BuildsErrorState'
import BuildsLoadingState from './BuildsLoadingState'
import EmptyBuildsState from './EmptyBuildsState'

interface BuildRecordsContentProps {
  records: BuildRecord[]
  isLoading: boolean
  error: string | null
  downloadingUuid: string | null
  onDownload: (record: BuildRecord) => void
  onRetry: () => void
}

export default function BuildRecordsContent({
  records,
  isLoading,
  error,
  downloadingUuid,
  onDownload,
  onRetry,
}: BuildRecordsContentProps) {
  if (isLoading) {
    return <BuildsLoadingState />
  }

  if (error) {
    return <BuildsErrorState message={error} onRetry={onRetry} />
  }

  if (records.length === 0) {
    return <EmptyBuildsState />
  }

  return <BuildTable records={records} downloadingUuid={downloadingUuid} onDownload={onDownload} />
}