package io.internview.booking_service.web.dto;

import java.util.List;

import org.springframework.data.domain.Page;

import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class PageResponse<T> {

	List<T> items;
	int page;
	int size;
	long totalElements;
	int totalPages;
	boolean hasNext;
	boolean hasPrevious;

	public static <T> PageResponse<T> from(Page<T> page) {
		return PageResponse.<T>builder()
			.items(page.getContent())
			.page(page.getNumber())
			.size(page.getSize())
			.totalElements(page.getTotalElements())
			.totalPages(page.getTotalPages())
			.hasNext(page.hasNext())
			.hasPrevious(page.hasPrevious())
			.build();
	}
}
